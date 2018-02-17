require 'date'
require 'json'
module Quandl
  class DailyData
    def self.scrape_data(ticker,sdate,edate)
      begin
        json = Hash.new
        obj = Hash.new
        url = "https://www.quandl.com/api/v3/datasets/WIKI/#{ticker}.json?column_index=4&start_date=#{sdate}&end_date=#{edate}&collapse=daily&transform=none&api_key=S1T9cY2VHhk2kvRkQmjR"
        
        puts "Using Quandl to get data for start_date = #{sdate} ..end_date = #{edate} for ticker #{ticker} at url "
        puts "#{url}"
        page =  Nokogiri::HTML(open(url))
        json = page.css('p').children.text
        obj = JSON.parse(json)
        if obj["dataset"]["data"][0][1].nil?
          return "N/A"
        else
          return obj["dataset"]["data"][0][1]
        end
      end
    rescue Exception
      return "N/A"      
    end
  end
end
