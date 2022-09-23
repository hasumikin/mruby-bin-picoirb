#! /usr/bin/env ruby

case RUBY_ENGINE
when "ruby"
  require "io/console"
  require_relative "./terminal.rb"
  require_relative "./command.rb"

  class Sandbox
    def initialize
      @binding = binding
      @result = nil
      @state = 0
    end

    attr_reader :result, :state

    def compile(script)
      begin
        RubyVM::InstructionSequence.compile("_ = (#{script})")
        @script = script
      rescue SyntaxError => e
        #puts e.message
        return false
      end
      true
    end

    def resume
      begin
        @result = eval "_ = (#{@script})", @binding
      rescue => e
        puts e.message
        return false
      end
      true
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

class Shell
  TIMEOUT = 10_000 # 10 sec
  def initialize(default_mode)
    @default_mode = default_mode
    @terminal = Terminal::Line.new
    if RUBY_ENGINE == "ruby"
      @terminal.debug_tty = ARGV[0]
    end
    @terminal.feed = :lf
    @sandbox = Sandbox.new
    @sandbox.compile("nil") # _ = nil
    @sandbox.resume
  end

  def deinitialize
    puts "\nbye"
    terminate_irb
  end

  def start
    case @default_mode
    when :ruby
      @terminal.prompt = "ruby"
      run_ruby
    when :mrbsh
      @terminal.prompt = "sh"
      run_mrbsh
    end
    deinitialize
  end

  def run_mrbsh
    sandbox = @sandbox
    command = Command.new
    command.feed = @terminal.feed
    @terminal.start do |terminal, buffer, c|
      case c
      when 10, 13 # TODO depenging on the the "terminal"
        case args = buffer.dump.chomp.strip.split(" ")
        when []
          puts
        when ["quit"], ["exit"]
          break
        else
          print terminal.feed
          command.exec *args
          terminal.save_history
          buffer.clear
        end
      end
    end
  end

  def run_ruby
    sandbox = @sandbox
    @terminal.start do |terminal, buffer, c|
      case c
      when 10, 13 # TODO depenging on the the "terminal"
        case script = buffer.dump.chomp
        when ""
          puts
        when "quit", "exit"
          break
        else
          if buffer.lines[-1][-1] == "\\" || !sandbox.compile(script)
            buffer.put :ENTER
          else
            terminal.feed_at_bottom
            if sandbox.resume
              terminal.save_history
              n = 0
              # state 0: TASKSTATE_DORMANT == finished
              while sandbox.state != 0 do
                sleep_ms 50
                n += 50
                if n > TIMEOUT
                  puts "Error: Timeout (sandbox.state: #{sandbox.state})"
                end
              end
              print "=> #{sandbox.result.inspect}#{terminal.feed}"
            end
            buffer.clear
            terminal.history_head
          end
        end
      else
        terminal.debug c
      end
    end
  end
end

#shell = Shell.new(:ruby)
shell = Shell.new(:mrbsh)
shell.start
