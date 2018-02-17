module SecEdgar
  class Marketwatch
    def self.parse_ticker(ticker)
      analest = Hash.new{ |h,k| h[k] = Hash.new(&h.default_proc) }
      begin
        url = "https://www.marketwatch.com/investing/stock/" + ticker + "/analystestimates"
        puts "Getting analyst estimates for ticker: #{ticker}"
        puts "Market watch URL: #{url}"
        
        page =  Nokogiri::HTML(open(url))
        
      
        snap_rows = page.xpath("//table[@class='snapshot']/tbody")
        est_rows  = page.xpath("//table[@class='estimates']")
        
        snap_detail = Hash.new
        snap_rows.css(".first").each do |item|
          snap_detail[item.text.strip] = item.next_element.text.strip
        end
        if(snap_detail.empty?)
          analest[:"TargPrice"] = "N/A"
          analest[:"QMeanEst"]  = "N/A"
          analest[:"YMeanEst"]  = "N/A"
        else  
          analest[:"TargPrice"] = snap_detail["Average Target Price:"]
          analest[:"QMeanEst"]  = snap_detail["Current Quarters Estimate:"]
          analest[:"YMeanEst"]  = snap_detail["Current Year's Estimate:"]
        end
      #pp analest
      #below code gives Mean/Next year estimates.
      #est_details = Hash.new{|hash, key| hash[key] =Array.new;}
      #key = ""
      #est_rows.xpath("./tbody/tr/td").each do |item| 
      #  first_class = item['class']
      #  if(first_class.nil?)
      #    est_details[key.to_sym] << item.text.to_s.strip.to_f
      #  else
      #    key = item.text.to_s.strip
      #    next
      #  end
      #end
      #analest[:"Mean Estimate"][:"TQ"] =  est_details[:"Mean Estimate"][0]  
      ##analest[:"Mean Estimate"][:"NQ"] =  est_details[:"Mean Estimate"][1]
      #analest[:"Mean Estimate"][:"TY"] =  est_details[:"Mean Estimate"][2]
      ##analest[:"Mean Estimate"][:"NY"] =  est_details[:"Mean Estimate"][3]
      rescue Exception => exception
        puts "Encountered Exception while parsing URL, defaulting data to N/A"
        analest[:"TargPrice"] = "N/A"
        analest[:"QMeanEst"]  = "N/A"
        analest[:"YMeanEst"]  = "N/A"
      ensure
        return analest
      end
    end
  end
end

#est_rows.xpath("./tbody/tr/..").each do |item|
#  puts item.text.to_s.strip
#  puts item['class']
#end
#est_rows.css("tr").each do |item| 
#  first = item.children.first.text.to_s.strip
#  true if item.children.first 
#  est_details[first] = item.children.text.to_s.strip #[/[\w|\d\.\s+]+/]
#end
#pp est_details


#pp est_details
#est_rows.css('td.first').each do |node| 
#  pp   node.parent
#  puts node.text  
#  puts node.next_sibling 
#end

#est_rows.css(@class = estimate).each do |item| puts item.text.to_s.strip end
#pp est_rows.css("tr[1]/td[1]")
#pp est_rows.css("tr[1]/td[2]")
#pp est_rows.css("tr[1]/td[3]")
#pp est_rows.css("tr[1]/td[4]")
#pp est_rows.css("tr[1]/td[5]")
#puts est_rows.css("tr[2]")
#puts est_rows.css("tr[3]")
#puts est_rows.css("tr[4]")
#puts est_rows.css("tr[5]")

