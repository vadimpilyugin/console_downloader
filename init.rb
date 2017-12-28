require_relative 'printer'
require_relative 'interface'
require_relative 'menu'

require 'irb'
input_obj = Input.new(io:$stdin)
query_obj = QueryObject.new
sr_obj = SearchResultsObject.new(query_obj)
descr_obj = DescrObject.new(sr_obj)
cursor = Cursor.get
finalizer = FinalizerObject.new

menu = Menu.new(
	input_obj:input_obj,
	query_obj:query_obj, 
	sr_obj:sr_obj,
	descr_obj:descr_obj,
	finalizer:finalizer
)
begin
	loop {
		menu.main_loop
	}
rescue Interrupt

rescue StandardError => exc
	cursor.clear
	input_obj.make_cooked
	cursor.show
	puts exc.inspect
	puts exc.backtrace
ensure
	input_obj.make_cooked
	cursor.show
	cursor.clear
end