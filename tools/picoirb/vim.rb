#! /usr/bin/env ruby

if RUBY_ENGINE == "ruby"
  require_relative "./terminal.rb"
end

class Vim
  def initialize(filepath)
    @filepath = File.expand_path filepath, Dir.getwd
    @mode = :normal
    @terminal = Terminal::Editor.new
    @terminal.header_height= 0
    @terminal.footer_height = 2
    @command_buffer = Buffer.new
    unless @terminal.load_file_into_buffer(@filepath)
      @command_buffer.lines[0] == "No found"
    end
    @terminal.refresh_footer do |terminal|
      #     foreground  background
      print "\e[37;1m" ,"\e[48;5;239m"
      print " ", @filepath[0, terminal.height - 3].ljust(terminal.width - 1)
      print "\e[m" # reset color
      print "\e[1E"
      print @command_buffer.lines[0]
      if @mode == :command
        print "\e[#{terminal.width};1H"
        print "\e[#{@command_buffer.lines[0].size}C"
      else
        terminal.refresh_cursor
      end
    end
  end

  def start
    print "\e[?1049h" # DECSET 1049
    _start
    print "\e[?1049l" # DECRST 1049
  end

  def _start
    @terminal.start do |terminal, buffer, c|
      case @mode
      when :normal
        case c
        when  13 # LF
        when  27 # ESC
          case gets_nonblock(2)
          when "[A" # up
            buffer.put :UP
          when "[B" # down
            buffer.put :DOWN
          when "[C" # right
            buffer.put :RIGHT
          when "[D" # left
            buffer.put :LEFT
          end
        when  18 # Ctrl-R
        when  46 # . redo
        when  58 # ; command
        when  59 # : command
          @mode = :command
          @command_buffer.put ':'
        when  65 # A
        when  86 # V
        when  97 # a
        when  98 # b begin
        when 100 # d
        when 101 # e end
        when 103 # g
        when 104 # h left
          buffer.put :LEFT
        when 105 # i insert
          @mode = :insert
          @command_buffer.lines[0] = "Insert"
        when 106 # j down
          buffer.put :DOWN
        when 107 # k up
          buffer.put :UP
        when 108 # l right
          buffer.put :RIGHT
        when 111 # o replace
        when 112 # p paste
        when 114 # r replace
        when 117 # u undo
        when 118 # v visual
        when 119 # w word
        when 120 # x delete
        when 121 # y yank
        else
          puts c
        end
      when :command
        case c
        when 27 # ESC
          case gets_nonblock(2)
          when "[C" # right
            @command_buffer.put :RIGHT
          when "[D" # left
            @command_buffer.put :LEFT
          when nil
            @command_buffer.clear
            @mode = :normal
          end
        when 8, 127 # 127 on UNIX
          @command_buffer.put :BSPACE
          if @command_buffer.lines[0] == ""
            @mode = :normal
          end
        when 32..126
          @command_buffer.put c.chr
        end
      when :insert
        case c
        when 27 # ESC
          case gets_nonblock(2)
          when nil
            @command_buffer.clear
            @mode = :normal
          end
        end
      when :visual
      when :visual_line
      when :visual_block
      end
    end
  end
end


vim = Vim.new(ARGV[0])
vim.start

