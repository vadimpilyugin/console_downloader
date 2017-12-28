require_relative 'http_tools'

class HtmlTools

  B = 1
  KB = 2**10
  MB = 2**20
  GB = 2**30
  TB = 2**40  
  
  def self.hr_to_mach_size(s)
    if s !~ /(?<size>\d+(\.\d+)?)/
      puts "Wrong size: #{s}"
    else
      f = $~['size'].to_f
      mult = case s
        when /KB/
          KB
        when /MB/
          MB
        when /GB/
          GB
        when /TB/
          TB
        when /B/
          B
      end
      f *= mult
    end
    f.to_i
  end
  
  def self.tr_to_row(tr)
    # puts tr.css('td')[3].css('a.tLink').map{|elem| elem['href']}.first
    {
      hr_size:tr.css('td')[5].text.gsub(/(\n|\t)/,' '),
      category:tr.css('td')[2].text.gsub(/(\n|\t)/,''),
      name:tr.css('td')[3].text.gsub(/(\n|\t)/,''),
      seeds:tr.css('td')[6].css('u').text,
      link_to_thread:HttpTools::BASE_URL+tr.css('td')[3].css('a.tLink').first['href']
    }
  end
  
  def self.prettify_entry(entry)
    entry[:hr_size] =~ /\d+\s*(?<size>\d+(\.\d+)?.(B|KB|MB|GB|TB))/
    if $~.nil?
      puts entry
      raise StandardError.new("Неверный формат размера!")
    end
    entry[:hr_size] = $~['size']
    entry[:size] = hr_to_mach_size($~['size'])
    # delete descr from name
    entry[:name].sub!(/^\([^()]*\)\s*/, '')
    # seeds to int
    entry[:seeds] = entry[:seeds].to_i
    entry
  end
  def self.extract_dl_link(html)
    doc = Nokogiri::HTML html
    HttpTools::BASE_URL+doc.css('a.dl-link').first['href']
  end
  
  def self.extract_descr(html)
    doc = Nokogiri::HTML html
    descr = doc.css('div.post_body').text.split("\n").keep_if{|l|l.strip.size > 0}
    i = descr.index{|s| s =~ /MediaInfo/}
    i = descr.size if i.nil?
    return descr.first(i)
  end
end