# Learn "Terminal modes"
# https://www.ibm.com/docs/en/linux-on-systems?topic=wysk-terminal-modes
#
class Terminal
  MIN_ROWS = 24
  MIN_COLS = 80

  case RUBY_ENGINE
  when "ruby"
    def getch
      STDIN.getch.ord
    end
    def gets_nonblock(max)
      STDIN.noecho{ |input| input.read_nonblock(max) }
    end
    def get_position_report
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
  def initialize(mode = :line)
    @mode = mode
    @row_size = 0
    @col_size = 0
    get_size
    @buffer = Buffer.new
    prompt = ""
    @prev_cursor_y = 0
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
    y, x = get_position_report
    home
    print "\e[999B" # cursor down * 999
    print "\e[999C" # cursor left * 999
    @row_size, @col_size = get_position_report
    print "\e[#{y};#{x}H"
  end

  def draw_frame
    clear
    home
    if @col_size < MIN_COLS || @row_size < MIN_ROWS
      puts "Terminal should be larger than col:#{MIN_COLS} * row:#{MIN_ROWS}"
      puts "(Now it's col:#{@col_size} * row:#{@row_size})"
      puts "Resize screen then press Ctrl+L to refresh"
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
    print "Ctrl+D to quit / Ctrl+L to refresh screen #".rjust(@col_size)
  end

  def adjust_screen
    adjust = physical_line_count - @prev_cursor_y + 1
    debug adjust
    print "\e[#{adjust}B"
    @prev_cursor_y = 0
    puts
  end

  def physical_line_count
    count = 0
    @buffer.lines.each do |line|
      count += 1 + (@prompt_margin + line.length) / @col_size
    end
    count
  end

  FEED = "\n"

  def refresh_line
    get_size

    line_count = physical_line_count

    if 0 < @prev_cursor_y
      print "\e[#{@prev_cursor_y}F"
    else
      print "\e[1G"
    end
    print "\e[0J"

    scroll = line_count - (@row_size - get_position_report[0]) - 1
    if 0 < scroll
      print "\e[#{scroll}S\e[#{scroll}A"
    end

    @buffer.lines.each_with_index do |line, i|
      print @prompt
      if i == 0
        print "> "
      else
        print "* "
      end
      print line
      if (@prompt_margin + line.length) % @col_size == 0
        print "\e[1E"
      end
      print FEED if @buffer.lines[i + 1]
    end

    print "\e[#{line_count}F"
    @prev_cursor_y = -1
    @buffer.lines.each_with_index do |line, i|
      break if i == @buffer.cursor[:y]
      c = (@prompt_margin + line.length) / @col_size + 1
      print "\e[#{c}B"
      @prev_cursor_y += c
    end
    a = (@prompt_margin + @buffer.cursor[:x]) / @col_size + 1
    print "\e[#{a}B" if 0 < a
    @prev_cursor_y += a
    b = (@prompt_margin + @buffer.cursor[:x]) % @col_size
    print "\e[#{b}C" if 0 < b
  end

  def start
    while true
      if @mode == :line
        refresh_line
      else
        refresh_fullscreen
      end
      c = getch
      case c
      when 1 # Ctrl-A
        # head
      when 3 # Ctrl-C
        print "SIGINT"
        break
      when 4 # Ctrl-D
        print "logout"
        break
      when 5 # Ctrl-E
        # tail
      when 9
        @buffer.put :TAB
      when 12 # Ctrl-L
        get_size
      when 26 # Ctrl-Z
        print "shunt" # Shunt into the background
        break
      when 27 # ESC
        case gets_nonblock(2)
        when "[A"
          @buffer.put :UP
        when "[B"
          @buffer.put :DOWN
        when "[C"
          @buffer.put :RIGHT
        when "[D"
          @buffer.put :LEFT
        else
          # TODO: ?
        end
      when 8, 127 # 127 on UNIX
        @buffer.put :BSPACE
      when 32..126
        @buffer.put c.chr
      else
        yield @buffer, c
        `echo "#{c}" > /dev/pts/5`
        # ignore
      end
    end
  end

  def debug(text)
    `echo "#{text}" > /dev/pts/10`
  end

end

