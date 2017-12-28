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
  def draw_window
    system 'clear'
    puts "Введите запрос. Он будет отправлен на rutracker.org\r\n".green+''.white
    print '> '
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
  def redraw_selected(color=:green)
    return if entries.nil? || entries.empty?
    @cursor.move_to(@selected,Cursor::FIRST_COL)
    print_entry(entries[@selected],color,@offset)
    @offset += 1
    # @cursor.move_to(@selected,Cursor::FIRST_COL)
  end
  def print_entry(entry,color,offset=0)
    name_len = 30
    name = entry[:name]
    if name.size > name_len
      name = entry[:name] + ' '*5
      name = name.my_range(offset%name.size,(name_len+offset)%name.size)
      name = complete(name, name_len)
    else
      name = complete(name, name_len)
    end
    category_len = 20
    category = entry[:category]
    if category.size > category_len
      category = entry[:category] + ' '*5
      category = category.my_range(offset%category.size,(category_len+offset)%category.size)
      category = complete(category, category_len)
    else
      category = complete(category, category_len)
    end

    size = complete(entry[:hr_size][0...10], 10)
    seeds = entry[:seeds].to_s # не надо ограничивать
    space = " "*5
    @cursor.print(
      category+space+name+space+size+space+seeds,
      color
    )
  end
  def action_on_arrow(c)
    @offset = 0
    if c == Input::ARROW_UP && @selected > 0
      redraw_selected(:white)
      @selected -= 1
      redraw_selected(:green)
    elsif c == Input::ARROW_DOWN && @selected < entries.size-1
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
  TORRENT_FOLDER = '/home/vadim/torrents/'

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
    system 'clear'
    @cursor.hide
    draw_descr
  end
  def descr
    HtmlTools.extract_descr(html).first(Cursor::MAX_ROWS-2).select{|line|
      line.size < 200 && line !~ /(раздач|криншот|равнен|тех. данн)/
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
    filename = TORRENT_FOLDER+name+'.torrent'
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