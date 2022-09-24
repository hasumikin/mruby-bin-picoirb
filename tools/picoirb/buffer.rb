if RUBY_ENGINE == "mruby/c"
  class Integer
    alias to_int to_i
  end
  class Array
    def insert(index, *vals)
      index_int = index.to_int
      if index_int < 0
        raise ArgumentError, "Negative index doesn't work"
      end
      tail = self[index_int, self.length]
      vals.each_with_index do |val, i|
        self[index_int + i] = val
      end
      if tail
        tail_at = index_int + vals.count
        tail.each do |elem|
          self[tail_at] = elem
          tail_at += 1
        end
      end
      self
    end
  end
end

class Buffer
  def initialize
    @cursor = {x: 0, y: 0}
    clear
  end

  attr_accessor :lines
  attr_reader :cursor

  def current_line
    @lines[@cursor[:y]]
  end

  def clear
    @lines = [""]
    home
  end

  def dump
    @lines.map do |line|
      line[-1] == "\\" ? line[0, line.length - 1] : line
    end.join("\n")
  end

  def home
    @cursor[:x] = 0
    @cursor[:y] = 0
  end

  def head
    @cursor[:x] = 0
  end

  def tail
    @cursor[:x] = current_line.length
  end

  def bottom
    @cursor[:y] = @lines.count - 1
  end

  def left
    if 0 < @cursor[:x] && 0 < current_line.length
      tail if current_line.length < @cursor[:x]
      @cursor[:x] -= 1
    elsif 0 < @cursor[:y]
      up
      tail
    end
  end

  def right
    if @cursor[:x] < current_line.length
      @cursor[:x] += 1
    else
      if @cursor[:y] + 1 < @lines.length
        down
        head
      end
    end
  end

  def up
    if 0 < @cursor[:y]
      @cursor[:y] -= 1
      @prev_c = :UP
    end
  end

  def down
    if @cursor[:y] + 1 < @lines.length
      @cursor[:y] += 1
      @prev_c = :DOWN
    end
  end

  def put(c)
    line = current_line
    if c.is_a?(String)
      line = line[0, @cursor[:x]].to_s + c + line[@cursor[:x], 65535].to_s
      @lines[@cursor[:y]] = line
      right
    else
      case c
      when :TAB
        put " "
        put " "
      when :ENTER
        new_line = line[@cursor[:x], 65535]
        @lines[@cursor[:y]] = line[0, @cursor[:x]].to_s
        @lines.insert(@cursor[:y] + 1, new_line) if new_line
        head
        down
      when :BSPACE
        if 0 < @cursor[:x]
          line = line[0, @cursor[:x] - 1].to_s + line[@cursor[:x], 65535].to_s
          @lines[@cursor[:y]] = line
          left
        else
          if 0 < @cursor[:y]
            @cursor[:x] = @lines[@cursor[:y] - 1].length
            @lines[@cursor[:y] - 1] += current_line
            @lines.delete_at @cursor[:y]
            up
          end
        end
      when :DOWN
        down
      when :UP
        up
      when :RIGHT
        right
      when :LEFT
        left
      when :HOME
        home
      end
    end
  end

  def current_tail(n = 1)
    current_line[@cursor[:x] - n, 65535].to_s
  end

end

$buffer_lock = true
