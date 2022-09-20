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

terminal = Terminal::Line.new
terminal.debug_tty = ARGV[0]
terminal.feed = :lf
terminal.prompt = "picoirb"

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
        terminal.feed_at_bottom
        if sandbox.compile(script)
          terminal.save_history
          if sandbox.resume
            n = 0
            while sandbox.state != 0 do # 0: TASKSTATE_DORMANT == finished(?)
              sleep_ms 50
              n += 50
              if n > TIMEOUT
                puts "Error: Timeout (sandbox.state: #{sandbox.state})"
              end
            end
            print "=> #{sandbox.result.inspect}#{terminal.feed}"
          end
        end
        buffer.clear
      end
    end
  else
    terminal.debug c
  end
end

puts "\nbye"
sandbox.exit
terminate_irb

