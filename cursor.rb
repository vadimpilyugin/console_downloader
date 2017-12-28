require 'tty-cursor'
require 'io/console'

require_relative 'printer'

class Cursor
  MAX_ROWS,MAX_COLS = STDIN.winsize
  LAST_COL = MAX_COLS-1
  LAST_ROW = MAX_ROWS-1
  MIDDLE_COL = MAX_COLS/2
  MIDDLE_ROW = MAX_ROWS/2
  FIRST_ROW = 0
  FIRST_COL = 0
private
  def initialize
    @cursor = TTY::Cursor
    @pos_stack = []
    @hidden = false
    clear
  end
public
  def self.get
  	return @cursor if @cursor
  	@cursor = new
  end
  def real_print(s)
    $stdout.print s
  end
  def clear
    @row = FIRST_ROW
    @col = FIRST_COL
    real_print @cursor.clear_screen
    move_to
  end
  def move_to(row = @row,col = @col)
    assert(row,col)

    @row = row
    @col = col
    real_print @cursor.move_to(col,row)
  end
  def move(row,col)
    assert(@row+row,@col+col)

    @row += row
    @col += col
    real_print @cursor.move(col,-row)
  end
  def assert(row,col)
    if row < FIRST_ROW ||
      row >= MAX_ROWS ||
      col < FIRST_COL ||
      col >= MAX_COLS

      raise "Out of range: (#{row},#{col})"
    end
  end
  def erase(n,fg=:white)
    real_print ''.public_send(fg)
    move_to
    real_print @cursor.clear_char(n)
    move_to
  end
  def print(s,fg = :white)
    erase(s.size,fg)
    real_print s
    @col += s.size
  end
  def save_pos
    @pos_stack << [@row,@col]
  end
  def restore_pos
    @row,@col = @pos_stack.pop
    move_to(@row,@col)
  end
  def print_at(row,col,s,fg = :white)
    assert(row,col)

    save_pos
    move_to(row,col)
    print(s,fg)
    restore_pos
  end
  def hide
  	return if @hidden
  	print @cursor.hide
  	@hidden = true
  end
  def show
  	return if !@hidden
  	print @cursor.show
  	@hidden = false
  end
end