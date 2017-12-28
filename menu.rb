require 'io/console'

class Input
  RAW = 0
  COOKED = 1
  CSI = "\e["
  ARROW_UP = CSI+'A'
  ARROW_DOWN = CSI+'B'
  ARROW_RIGHT = CSI+'C'
  ARROW_LEFT = CSI+'D'
  CTRL_C = "\x03"
  CTRL_D = "\x04"
  QUIT = 'q'
  ENTER = "\r"
  
  def initialize(io:,mode:COOKED)
    @io = io
    @mode = mode
  end
  def get(secs=nil)
    case @mode
    when COOKED
      if s = @io.gets
        s.chomp
      else
        nil
      end
    when RAW
    	Printer::debug(msg: "Mode = RAW")
    	if select(secs).nil?
    		nil
    	else
      	get_char_or_sequence
      end
    end
  end
  def make_raw
  	return if @mode == RAW
    @io.raw!
    @mode = RAW
  end
  def make_cooked
  	return if @mode == COOKED
    @io.cooked!
    @mode = COOKED
  end
  def select(secs)
  	if secs
  		IO.select([$stdin],[],[],secs)
  	else
  		IO.select([$stdin])
  	end
  end
private
  def get_char_or_sequence
    result = ''
	  while @io.ready?
	    result << @io.sysread(1)
	  end
	  result
  end
end

class Menu
  QUERY = 0
  SEARCH_RESULTS = 1
  DESCR = 2
  SUCCESS = 3
  
  def initialize(input_obj:,query_obj:, sr_obj:,descr_obj:,finalizer:)
    @state = QUERY
    @input = input_obj
    @cursor = Cursor.get
		@input_obj = input_obj
		@query_obj = query_obj
		@sr_obj = sr_obj
		@descr_obj = descr_obj
		@finalizer = finalizer
  end
  def preps
  	case @state
  	when QUERY
  		@input.make_cooked
      @cursor.show
  		@query_obj.draw_window
    when SEARCH_RESULTS
			@input.make_raw
    when DESCR
			@descr_obj.draw_window
      @input.make_raw
    when SUCCESS
    	@input.make_cooked
    end
  end
  def main_loop
  	preps
    case @state
    when QUERY
      s = @input.get
      if s.nil?
        @state = SUCCESS
      elsif s == Input::QUIT
        @state = SUCCESS
      elsif s.empty?
        @state = QUERY
      else
        @query_obj.process_query(s)
        @sr_obj.draw_window
        @state = SEARCH_RESULTS
      end
    when SEARCH_RESULTS
      c = @input.get(0.4)
      if c.nil?
      	# timeout, redraw selected entry
      	@sr_obj.redraw_selected
      elsif c == Input::QUIT
        @state = QUERY
      elsif c == Input::ARROW_UP || c == Input::ARROW_DOWN
        @sr_obj.action_on_arrow(c)
      elsif c == Input::CTRL_C
        @state = SUCCESS
      elsif c == Input::ENTER
        @sr_obj.register_entry
        @state = DESCR
      end
    when DESCR
      c = @input.get
      if c == Input::ARROW_UP || c == Input::ARROW_DOWN
        @descr_obj.action_on_arrow(c)
      elsif c == Input::QUIT
      	@sr_obj.draw_window
        @state = SEARCH_RESULTS
      elsif c == Input::CTRL_C
        @state = SUCCESS
      elsif c == Input::ENTER
        @descr_obj.selected
        @sr_obj.draw_window
        @state = SEARCH_RESULTS
      end
    when SUCCESS
      @finalizer.finalize
      raise Interrupt
    end
  end
end