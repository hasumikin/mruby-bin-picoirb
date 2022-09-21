#include <stdbool.h>
#include <time.h>
#include <stdio.h>
#include <stdlib.h>
#include <termio.h>
#include <errno.h>
#include <fcntl.h>
#include <mrubyc.h>

#if defined(PICORUBY_DEBUG) && !defined(MRBC_ALLOC_LIBC)
  #include <alloc.c>
#endif

#include <picorbc.h>

#include "heap.h"

/* Ruby */
#include "buffer.c"
#include "terminal.c"
#include "irb.c"

#include "sandbox.h"

int sigint;
int loglevel;
static uint8_t heap[HEAP_SIZE];

void
c_get_cursor_position(mrb_vm *vm, mrb_value *v, int argc)
{
  static struct termios state, oldstate;
  char buf[10];
  char *p1 = buf;
  char *p2 = NULL;
  char c;
  int row = 0;
  int col = 0;

  // echo off
  tcgetattr(0, &oldstate);
  state = oldstate;
  state.c_lflag &= ~(ICANON | ECHO);
  tcsetattr(0, TCSANOW, &state);

  // report cursor position
  write(0,"\e[6n",4);

  for (;;) {
    read(0, &c, 1);
    if(0x30 <= c && c <= 0x39) *p1++ = c;
    if(c == ';') {
      *p1++ = '\0';
      row = atoi(buf);
      p2 = p1;
    }
    if(c == 'R') break;
  }
  *p1 = '\0';
  col = atoi(p2);

  // echo on
  tcsetattr(0, TCSANOW, &oldstate);

  mrbc_value return_val = mrbc_array_new(vm, 2);
  mrbc_array *rb_array = return_val.array;
  rb_array->n_stored = 2;
  if (row && col) {
    mrbc_set_integer(rb_array->data, row);
    mrbc_set_integer(rb_array->data + 1, col);
  } else {
    mrbc_raise(vm, MRBC_CLASS(Exception), "get_cursor_position failed");
  }
  SET_RETURN(return_val);
}

void
c_getch(mrb_vm *vm, mrb_value *v, int argc)
{
  struct termios save_settings;
  struct termios settings;
  tcgetattr( fileno( stdin ), &save_settings );
  settings = save_settings;
  settings.c_lflag &= ~( ECHO | ICANON ); /* no echoback & no wait for LF */
  tcsetattr( fileno( stdin ), TCSANOW, &settings );
  fcntl( fileno( stdin ), F_SETFL, O_NONBLOCK ); /* non blocking */
  int c;
  for (;;) {
    c = getchar();
    if (c != EOF) break;
    if (sigint) {
      c = 3;
      sigint = 0;
      break;
    }
  }
  SET_INT_RETURN(c);
  tcsetattr( fileno( stdin ), TCSANOW, &save_settings );
}

void
c_gets_nonblock(mrb_vm *vm, mrb_value *v, int argc)
{
  size_t max_len = GET_INT_ARG(1) + 1;
  char buf[max_len];
  struct termios save_settings;
  struct termios settings;
  tcgetattr( fileno( stdin ), &save_settings );
  settings = save_settings;
  settings.c_lflag &= ~( ECHO | ICANON ); /* no echoback & no wait for LF */
  tcsetattr( fileno( stdin ), TCSANOW, &settings );
  fcntl( fileno( stdin ), F_SETFL, O_NONBLOCK ); /* non blocking */
  int c;
  size_t len;
  for(len = 0; len < max_len; len++) {
    c = getchar();
    if ( c == EOF ) {
      break;
    } else {
      buf[len] = c;
    }
  }
  buf[len] = '\0';
  tcsetattr( fileno( stdin ), TCSANOW, &save_settings );
  mrb_value value = mrbc_string_new(vm, (const void *)&buf, len);
  SET_RETURN(value);
}

#include <signal.h>

void
signal_handler(int _no)
{
  sigint = 1;
}

void
ignore_sigint(void)
{
  sigint = 0;
  struct sigaction sa;
  memset(&sa, 0, sizeof(struct sigaction));
  sa.sa_handler = signal_handler;
  sa.sa_flags = 0;
  if( sigaction( SIGINT, &sa, NULL ) < 0 ) {
    perror("sigaction");
  }
}

void
default_sigint(void)
{
  struct sigaction sa;
  memset(&sa, 0, sizeof(struct sigaction));
  sa.sa_handler = SIG_DFL;
  if( sigaction( SIGINT, &sa, NULL ) < 0 ) {
    perror("sigaction");
  }
}

void
c_terminate_irb(mrb_vm *vm, mrb_value *v, int argc)
{
  default_sigint();
  raise(SIGINT);
}

int
main(int argc, char *argv[])
{
  loglevel = LOGLEVEL_FATAL;
  mrbc_init(heap, HEAP_SIZE);
  mrbc_define_method(0, mrbc_class_object, "get_cursor_position", c_get_cursor_position);
  mrbc_define_method(0, mrbc_class_object, "getch", c_getch);
  mrbc_define_method(0, mrbc_class_object, "gets_nonblock", c_gets_nonblock);
  mrbc_define_method(0, mrbc_class_object, "terminate_irb", c_terminate_irb);
  SANDBOX_INIT();
  create_sandbox();
  mrbc_create_task(buffer, 0);
  mrbc_create_task(terminal, 0);
  mrbc_create_task(irb, 0);
  ignore_sigint();
  mrbc_run();
  return 0;
}
