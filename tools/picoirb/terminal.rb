# Learn "Terminal modes"
# https://www.ibm.com/docs/en/linux-on-systems?topic=wysk-terminal-modes
#
class Terminal

  class Base
    case RUBY_ENGINE
    when "ruby"
      def getch
        STDIN.getch.ord
      end
      def gets_nonblock(max)
        STDIN.noecho{ |input| input.read_nonblock(max) }
      end
      def get_cursor_position
        res = ""
        STDIN.raw do |stdin|
          STDOUT << "\e[6n"
          STDOUT.flush
          while (c = stdin.getc) != 'R'
            res << c if c
          end
        end
        STDIN.iflush
        _size = res.split(";")
        return [_size[0][2, 3].to_i, _size[1].to_i]
      end
    end

    # mode: :fullscreen | :line
    def initialize
      self.feed = :crlf
      get_size
      @buffer = Buffer.new
      prompt = ""
      @prev_cursor_y = 0
    end

    attr_reader :feed
    attr_accessor :debug_tty

    def feed=(arg)
      @feed = arg == :lf ? "\n" : "\r\n"
    end

    def prompt=(word)
      @prompt = word
      @prompt_margin = 2 + @prompt.length
    end

    def clear
      print "\e[2J"
    end

    def home
      print "\e[1;1H"
    end

    def get_size
      y, x = get_cursor_position # save current position
      home
      print "\e[999B\e[999C" # down * 999 and right * 999
      @row_size, @col_size = get_cursor_position
      debug "#{@row_size};#{@col_size}" # restore original position
      print "\e[#{y};#{x}H" # restore original position
    end

    def physical_line_count
      count = 0
      @buffer.lines.each do |line|
        count += 1 + (@prompt_margin + line.length) / @col_size
      end
      count
    end

    def debug(text)
      if @debug_tty && RUBY_ENGINE == 'ruby'
        system "echo '#{text}' > /dev/pts/#{@debug_tty}"
      end
    end

  end

  class Line < Base
    def initialize
      @history = Array.new
      @history_index = 0
      super
    end

    MAX_HISTORY_COUNT = 10

    def history_head
      @history_index = @history.count
    end

    def save_history
      if @history[-1] != @buffer.lines
        @history << @buffer.lines
      end
      if MAX_HISTORY_COUNT < @history.count
        @history.shift
      end
      history_head
    end

    def load_history(dir)
      if dir == :up
        return if @history_index == 0
        @history_index -= 1
      else
        return if @history_index == @history.count - 1
        @history_index += 1
      end
      unless @history.empty?
        @buffer.lines = @history[@history_index]
        @buffer.bottom
        @buffer.tail
      end
      refresh
    end

    def feed_at_bottom
      adjust = physical_line_count - @prev_cursor_y - 1
      print "\e[#{adjust}B" if 0 < adjust
      print "\e[999C" # right * 999
      print @feed
      @prev_cursor_y = 0
    end

    def refresh
      get_size

      line_count = physical_line_count

      # Move cursor to the top of the snippet
      if 0 < @prev_cursor_y
        print "\e[#{@prev_cursor_y}F"
      else
        print "\e[1G"
      end
      print "\e[0J" # Delete all after the cursor

      # Scroll screen if necessary
      scroll = line_count - (@row_size - get_cursor_position[0]) - 1
      if 0 < scroll
        print "\e[#{scroll}S\e[#{scroll}A"
      end

      # Show the buffer
      @buffer.lines.each_with_index do |line, i|
        print @prompt
        if i == 0
          print "> "
        else
          print "* "
        end
        print line
        if (@prompt_margin + line.length) % @col_size == 0
          # if the last letter is on the right most of the window,
          # move cursor to the next line's head
          print "\e[1E"
        end
        print @feed if @buffer.lines[i + 1]
      end

      # move the cursor where supposed to be
      print "\e[#{line_count}F"
      @prev_cursor_y = -1
      @buffer.lines.each_with_index do |line, i|
        break if i == @buffer.cursor[:y]
        a = (@prompt_margin + line.length) / @col_size + 1
        print "\e[#{a}B"
        @prev_cursor_y += a
      end
      b = (@prompt_margin + @buffer.cursor[:x]) / @col_size + 1
      print "\e[#{b}B"
      @prev_cursor_y += b
      c = (@prompt_margin + @buffer.cursor[:x]) % @col_size
      print "\e[#{c}C" if 0 < c
    end

    def start
      while true
        refresh
        c = getch
        case c
        when 1 # Ctrl-A
          @buffer.head
        when 3 # Ctrl-C
          @buffer.bottom
          @buffer.tail
          print @feed, "^C\e[0J", @feed
          @prev_cursor_y = 0
          @buffer.clear
          history_head
        when 4 # Ctrl-D logout
          print @feed
          return
        when 5 # Ctrl-E
          @buffer.tail
        when 9
          @buffer.put :TAB
        when 12 # Ctrl-L
          refresh
        when 26 # Ctrl-Z
          print @feed, "shunt" # Shunt into the background
          break
        when 27 # ESC
          case gets_nonblock(2)
          when "[A"
            if @prev_cursor_y == 0
              load_history :up
            else
              @buffer.put :UP
            end
          when "[B"
            if physical_line_count == @prev_cursor_y + 1
              load_history :down
            else
              @buffer.put :DOWN
            end
          when "[C"
            @buffer.put :RIGHT
          when "[D"
            @buffer.put :LEFT
          else
            debug c
          end
        when 8, 127 # 127 on UNIX
          @buffer.put :BSPACE
        when 32..126
          @buffer.put c.chr
        else
          yield @buffer, c
        end
      end
    end

  end

  class FullScreen < Base
    MIN_ROWS = 24
    MIN_COLS = 80

    def draw_frame
      clear
      home
      if @col_size < MIN_COLS || @row_size < MIN_ROWS
        print "Terminal should be larger than col:#{MIN_COLS} * row:#{MIN_ROWS}#{@feed}"
        print "(Now it's col:#{@col_size} * row:#{@row_size})#{@feed}"
        print "Resize screen then press Ctrl+L to refresh#{@feed}"
        return
      end
      print "#" * @col_size
      home
      print "\e[B"
      (@row_size - 2).times do |row|
        print "#"
        print " " * (@col_size - 2)
        print "#"
      end
      print "Ctrl+D to quit | Ctrl+L to refresh screen #".rjust(@col_size)
    end

  end
end

