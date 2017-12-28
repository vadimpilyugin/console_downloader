require 'irb'
require 'yaml'
$config = YAML.load_file('config.yml')

require_relative 'src/printer'
require_relative 'src/interface'
require_relative 'src/menu'


begin
	cursor = Cursor.get
	input_obj = Input.new(io:$stdin)
	
	Printer::assert(
		expr:Dir.exists?($config['torrents_dir']),
		msg:"torrents_dir does not exist!"
	)

	query_obj = QueryObject.new
	sr_obj = SearchResultsObject.new(query_obj)
	descr_obj = DescrObject.new(sr_obj)
	finalizer = FinalizerObject.new

	menu = Menu.new(
		input_obj:input_obj,
		query_obj:query_obj, 
		sr_obj:sr_obj,
		descr_obj:descr_obj,
		finalizer:finalizer
	)
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