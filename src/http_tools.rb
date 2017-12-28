require 'net/http'
require 'nokogiri'

class HttpTools
  BASE_URL = 'https://rutracker.org/forum/'
  SEARCH_URL = 'https://rutracker.org/forum/tracker.php'
  COOKIE = $config['cookie']
  
  @cookie = COOKIE
  
  def self.make_search_request(url:,data:)
    uri = URI(url)
    req = Net::HTTP::Post.new(uri)
    req['Content-Type'] = 'application/x-www-form-urlencoded'
    req['Cookie'] = @cookie
    req.set_form_data('nm' => data.to_s)

    res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => true) do |http|
      http.request(req)
    end
    res.body
  end
  def self.make_request(url:)
    uri = URI(url)
    req = Net::HTTP::Get.new(uri)
    req['Cookie'] = @cookie

    res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => true) do |http|
      http.request(req)
    end
    res.body
  end
end