#! /usr/bin/env ruby

case RUBY_ENGINE
when "ruby"
  require "io/console"
  require_relative "./terminal.rb"
  require_relative "./buffer.rb"

  class Sandbox
    def initialize
      @binding = binding
      @result = nil
      @state = 0
    end

    attr_reader :result, :state

    def compile(script)
      begin
        RubyVM::InstructionSequence.compile(script)
      rescue SyntaxError => e
        puts e.message
        return false
      end
      begin
        @result = eval "_ = (#{script})", @binding
      rescue => e
        puts e.message
        return false
      end
      true
    end

    def resume
      true
    end

    def exit
    end
  end

  def terminate_irb
    exit
  end

when "mruby/c"
  while !$buffer_lock
    relinquish
  end
end

TIMEOUT = 10_000 # 10 sec
PROMPT = "picoirb"

terminal = Terminal.new(:line)
terminal.prompt = PROMPT

sandbox = Sandbox.new
sandbox.compile("nil") # _ = nil
sandbox.resume

terminal.start do |buffer, c|
  case c
  when 10, 13
    script = buffer.dump.chomp
    case script
    when ""
      puts
    when "quit", "exit"
      break
    else
      if buffer.lines[-1][-1] == "\\"
        buffer.put :ENTER
      else
        terminal.adjust_screen
        buffer.clear
        if sandbox.compile(script)
          if sandbox.resume
            n = 0
            while sandbox.state != 0 do # 0: TASKSTATE_DORMANT == finished(?)
              sleep_ms 50
              n += 50
              if n > TIMEOUT
                puts "Error: Timeout (sandbox.state: #{sandbox.state})"
              end
            end
            print "=> "
            p sandbox.result
          end
        end
      end
    end
  else
    terminal.debug c
  end
end

puts "\nbye"
sandbox.exit
terminate_irb

#while true
#  terminal.refresh_screen
#  c = getch
#  case c
#  when 3 # Ctrl-C
#    terminal.clear
#    terminal.adjust_screen
#  when 4 # Ctrl-D
#    exit_irb(sandbox)
#    break
#  when 9
#    terminal.put :TAB
#  when 10, 13
#  when 27 # ESC
#    case gets_nonblock(10)
#    when "[A"
#      terminal.put :UP
#    when "[B"
#      terminal.put :DOWN
#    when "[C"
#      terminal.put :RIGHT
#    when "[D"
#      terminal.put :LEFT
#    else
#      break
#    end
#  when 8, 127 # 127 on UNIX
#    terminal.put :BSPACE
#  when 32..126
#    terminal.put c.chr
#  else
#    # ignore
#  end
#  debug terminal.cursor
#end
