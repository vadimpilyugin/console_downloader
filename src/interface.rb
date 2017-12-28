require_relative 'http_tools'
require_relative 'html_tools'
require_relative 'cursor'

class Object
  def deep_clone
    return @deep_cloning_obj if @deep_cloning
    @deep_cloning_obj = clone
    @deep_cloning_obj.instance_variables.each do |var|
      val = @deep_cloning_obj.instance_variable_get(var)
      begin
        @deep_cloning = true
        val = val.deep_clone
      rescue TypeError
        next
      ensure
        @deep_cloning = false
      end
      @deep_cloning_obj.instance_variable_set(var, val)
    end
    deep_cloning_obj = @deep_cloning_obj
    @deep_cloning_obj = nil
    deep_cloning_obj
  end
end

module Enumerable 
  def stable_sort_by 
    sort_by.with_index { |x, idx| [yield(x), idx] } 
  end 
end

class InterfaceObject
  def draw_window
    
  end
end

class String
  def my_range(i1,i2)
    i = i1
    s = ''
    while i != i2
      s << self[i]
      i = (i+1) % self.size
    end
    s << self[i]
    s
  end
end

class QueryObject <InterfaceObject
  def initialize
    @cursor = Cursor.get
  end
  def draw_window
    @cursor.clear
    messages = [
      'Rutracker Downloader v1.0',
      '=========================',
      '',
      "Введите запрос. Он будет отправлен на rutracker.org",
      "Или введите 'q' для выхода",
      '',
    ].each_with_index {|msg,i|
      @cursor.move_to(i,Cursor::FIRST_COL)
      @cursor.print(msg,:green)
    }
    @cursor.move_to(messages.size,Cursor::FIRST_COL)
    @cursor.print('> ',:white)
  end
  def process_query(query)
    @query = query
    #TODO: HTTP encoding
    s = HttpTools.make_search_request(url:HttpTools::SEARCH_URL,data:query)
    doc = Nokogiri::HTML(s)
    # html to table
    table = doc.css('tr.hl-tr').map {|tr| HtmlTools.prettify_entry(HtmlTools.tr_to_row(tr))}
    # sort first by seeds desc, then by size desc
    table = table.sort_by{|elem| -elem[:size]}.stable_sort_by{|elem| -elem[:seeds]}#.map{|elem| [elem[:seeds],elem[:hr_size]]}
    @entries = table.select{|elem| elem[:seeds] > 0}
  end
  def entries
    @entries
    # require 'yaml'
    # YAML.load_file('menu.yml')['menu']
  end
  def query
    @query
  end
end

class SearchResultsObject <InterfaceObject
  
  def initialize(query_obj)
    @selected = 0
    @query_obj = query_obj
    @entries_cache = {}
    @cursor = Cursor.get
    @offset = 0
  end
  def entries
    return @entries_cache[@query_obj.query] if @entries_cache[@query_obj.query]
    @entries_cache[@query_obj.query] = @query_obj.entries
    @selected = 0
    @entries_cache[@query_obj.query]
  end
  def draw_window
    # system 'clear'
    @cursor.clear
    @cursor.hide
    if entries.empty?
      puts "По вашему запросу '#{@query_obj.query}' ничего не найдено!\r\n"
      puts "\r\n"
      puts "Нажмите 'q' для выхода".green+"\r\n".white
    else
      entries[0...Cursor::MAX_ROWS].each_with_index {|entry,i|
        @cursor.move_to(i,Cursor::FIRST_COL)
        if i == @selected
          print_entry(entry, :green, @offset)
        else
          print_entry(entry, :white)
        end
        # puts "\r\n" if i < Cursor::MAX_ROWS-1
      }
    end
  end
  def complete(s,to)
    s1 = s[0...to]
    s1 + ' '*(to-s1.size)
  end
  def cut(s,column_size,offset)
    s = s.to_s
    if s.size > column_size
      s = s + ' '*5
      s = s.my_range(offset % s.size,(column_size+offset) % s.size)
    end
    complete(s, column_size)
  end
  def redraw_selected(color=:green)
    return if entries.nil? || entries.empty?
    @cursor.move_to(@selected,Cursor::FIRST_COL)
    print_entry(entries[@selected],color,@offset)
    @offset += 1
    # @cursor.move_to(@selected,Cursor::FIRST_COL)
  end

  SPACE = ' '*5
  LAYOUT = [:category,:space,:name,:space,:hr_size,:space,:seeds]
  COLUMNS = {
    category: 30,
    name: 40,
    hr_size: 10,
    seeds: 5,
    space: 5 # * LAYOUT.count(:space)
  }
  def print_entry(entry,color,offset=0)
    part_len = Cursor::MAX_COLS/100.0
    # part_len = (Cursor::MAX_COLS - LAYOUT.count(:space)*SPACE.size)/LAYOUT.size
    columns = COLUMNS.transform_values {|v|(v*part_len).to_i }

    msg = {}
    entry[:space] = ' '*columns[:space]
    COLUMNS.each_key{|col| msg[col] = cut(entry[col], columns[col], offset)}
    entry.delete(:space)
    # msg[:space] = SPACE
    # msg[:name] = cut(entry[:name], columns[:name], offset)
    # msg[:category] = cut(entry[:category], columns[:category], offset)
    # msg[:size] = cut(entry[:hr_size],columns[:size])
    # msg[:seeds] = cut(entry[:seeds],columns[:seeds])

    LAYOUT.each{|column| @cursor.print(msg[column],color)}
  end
  def action_on_arrow(c)
    @offset = 0
    if c == Input::ARROW_UP && @selected > 0
      redraw_selected(:white)
      @selected -= 1
      redraw_selected(:green)
    elsif c == Input::ARROW_DOWN && @selected < Cursor::MAX_ROWS-1
      redraw_selected(:white)
      @selected += 1
      redraw_selected(:green)
    end
  end
  def register_entry
    @result = entries[@selected]
  end
  def selected_entry
    if entries
      entries[@selected]#.deep_clone
    else
      nil
    end
  end
end

class DescrObject <InterfaceObject

  def initialize(sr_obj)
    @cached_html = {}
    @line = 0
    @sr_obj = sr_obj
    @cursor = Cursor.get
  end
  def dl_link
    HtmlTools.extract_dl_link(html)
  end
  def draw_window
    @cursor.hide
    @cursor.clear
    draw_descr
  end
  def descr
    HtmlTools.extract_descr(html).first(Cursor::MAX_ROWS-2).select{|line|
      line.size < Cursor::MAX_COLS && line !~ /(раздач|криншот|равнен|тех. данн)/
    }.map{|line| line.gsub(/(\t|\n)/,'')}
  end
  def selected_entry
    @sr_obj.selected_entry
  end
  def html
    link = selected_entry[:link_to_thread]
    return @cached_html[link] if @cached_html[link]
    @cached_html[link] = HttpTools.make_request(url:link)
    @cached_html[link]
  end
  def draw_descr
    descr.each_with_index{|line,i| 
      @cursor.print_at(i,Cursor::FIRST_COL,line,:white)
    }
    msg = "Нажмите Enter, чтобы скачать .torrent файл"
    @cursor.print_at(Cursor::LAST_ROW,Cursor::FIRST_COL,msg,:green)
  end
  def action_on_arrow(c)
    if c == Input::ARROW_UP && @line > 0
      # @line -= 1
      # draw_window
    elsif c == Input::ARROW_DOWN && @line
      # @line += 1
      # draw_window
    end
  end
  def selected
    name = selected_entry[:name].gsub(/\//,',')
    filename = $config['torrents_dir']+name+'.torrent'
    msg = "Торрент файл сохранен по пути #{filename}"
    @cursor.print_at(Cursor::LAST_ROW,Cursor::FIRST_COL,msg,:white)
    torrent_file = HttpTools.make_request(url:dl_link)
    File.open(filename, 'w') {|f|
      f.write(torrent_file)
    }
  end
end

class FinalizerObject <InterfaceObject
  def finalize
    system 'clear'
  end
end