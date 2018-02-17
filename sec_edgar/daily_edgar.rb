#require 'sendgrid-ruby'
require 'rubygems'
require 'nokogiri'
require 'rexml/rexml'
require 'xmlrpc/client'
require 'open-uri'
require 'pp'
require "rest-client"
require "hpricot"
require 'dir'
require 'yaml'
require 'mail'
require 'active_support'
require 'active_support/core_ext/numeric'
require 'xbrlware-ruby19'
require 'xbrlware-extras'
require './Marketwatch'
require './Quandl'
require 'yahoofinance'
require 'date'
require 'json'
#include SendGrid

url_detail  = []
detail_hash = Hash.new
cmp_detail  = Array.new() {Hash.new}
period      = Hash.new
filings_xbrl = Array.new() {Hash.new}


detail = []
all_filings = []
cmp_ticker = ""
most_recent_entry = ""
file_type = {
  :report_type => nil
}


cwd = Dir.pwd
puts "Running daily_edgar for date: #{ARGV}"
if ARGV[0].empty?
  $todays_date     = Date.today
elsif ARGV[0] == "y"
  $todays_date     = Date.today - 1
else
  $todays_date = ARGV[0]
end
$todays_date = $todays_date.to_s
puts "DATE: #{$todays_date}"
DOWNLOAD_PATH_DATE = File.join("/home/manan/download/", $todays_date)
DOWNLOAD_PATH = File.join("/home/manan/download/", $todays_date ,"/filings/")
puts "Todays Download Path : #{DOWNLOAD_PATH}\n"

xbrl_links_file  = cwd.to_s + "/" + "data" + "/" + "xbrl_links___"     + $todays_date + ".yml"
$all_data_csv    = cwd.to_s + "/" + "data" + "/" + "all_data___"       + $todays_date + ".csv"

#Parse page using nokogiri, collect the company filings into array of hashes.
def items_with_segment_nil(instance=[],strings_to_search)
  fil_items = []
  strings_to_search.each do |string|
    items_all = @instance.item(string)
    if !items_all.empty?
      matching_item = 0
      items_all.each do |item_all|
        if (item_all.context.entity.segment.nil? )

          fil_items.push(item_all)
          matching_item = 1
        end
      end
    end
    return fil_items if matching_item == 1
  end
  return []
end

def func_xbrl_links(xbrl_links_file)
  filings       = []
  filings_xbrl  = Array.new() {Hash.new}

  @tdate        = $todays_date.split("-")
  date_str      = $todays_date.gsub("-","")
  #OLD way by parsing XML.
  #ftp_link = "https://www.sec.gov/Archives/edgar/daily-index/" + @tdate[0] + "/QTR1/sitemap." + date_str + ".xml"
  #todays_filings = daily.css('//text()').map(&:text).delete_if{|x| x !~ /htm/}.to_s
  #filings = todays_filings.gsub(/\[/,'').gsub(/\]/,'').gsub(/"/,'').gsub(/\s+/,'').split(",")
  tmonth = Date.xmlschema($todays_date).month

  if(tmonth.between?(1,3))
    qtrn = "QTR1"
  elsif(tmonth.between?(4,6))
    qtrn = "QTR2"
  elsif(tmonth.between?(7,9))
    qtrn = "QTR3"
  else
    qtrn = "QTR4"
  end
    
  ftp_link = "https://www.sec.gov/Archives/edgar/daily-index/" + @tdate[0] + "/#{qtrn}/crawler." + date_str + ".idx"
  puts "FTP_LINK:#{ftp_link}"
  daily = Nokogiri::HTML(open("#{ftp_link}"))
  @links = daily.css('//text()').to_s.split("\n").delete_if{|x| x !~ /htm/}
  @links = @links.delete_if{|x| x !~ /10-Q/ && x !~ /10-K/}
  filings = []
  @links.each do |link|
    #pp link
    link_str = link.to_s.match(/http:\/\/\S+htm/)
    filings.push(link_str[0])
  end

  filings[0] = "https://www.sec.gov/Archives/edgar/data/1595262/0001564590-15-000673-index.htm]"
  #ftp_link = "ftp://ftp.sec.gov/edgar/daily-index/2016/QTR2/sitemap.20160427.xml"
  #filings[0] = "http://www.sec.gov/Archives/edgar/data/1455926/0001052918-15-000259-index.htm"
  #filings[0]= "http://www.sec.gov/Archives/edgar/data/736913/0000898432-15-000678-index.htm"
  #filings[1]= "http://www.sec.gov/Archives/edgar/data/736913/0000898432-15-000678-index.htm"
  #filings[0]= "http://www.sec.gov/Archives/edgar/data/1455926/0001052918-15-000259-index.htm"
  #filings[1]= "http://www.sec.gov/Archives/edgar/data/1495899/0001144204-15-032143-index.htm"
  #filings[0] = "http://www.sec.gov/Archives/edgar/data/1099568/0001551163-16-000344-index.htm"
  #filings[0] =  "http://www.sec.gov/Archives/edgar/data/914208/0000914208-16-000923-index.htm"
  #FIXME: liabilities empty.https://www.sec.gov/Archives/edgar/data/817979/0000817979-16-000079-index.htm
  skip = 0
  filings.each do |url|
    pp url
    if(url !~ /https/)
      url = url.sub(/http/,"https")
    end
    #puts "Parsing #{url} for 10-Q/10-k"
    begin
      page = Nokogiri::HTML(open(url))
      #rescue OpenURI::HTTPError , SocketError , URI::InvalidURIError => details
    rescue URI::InvalidURIError
      puts "Service not available... trying next url"
      next
    rescue SocketError, OpenURI::HTTPError
      puts "Service not available...skipping #{url}"
      next
      #puts "Wait for a few minutes and make the request again"
      #sleep(2.minutes)
      #puts "Service not available... trying same #{url} again"
      #page = Nokogiri::HTML(open(url))
      #rescue OpenURI::HTTPError, SocketError => details
      #  puts "Failed to load the data: #{details} for second time"
      #  next
      #  #if skip == 1
      #  #  raise details
      #  #else
      #  #  skip = 0  #FIXME: Just ignore move to the next
      #  #  next
      #  #end
    end

    url_detail = page.css('div[@class = "formContent"] > div[@class = "formGrouping"]').children.map(&:text).delete_if {|x| x !~ /\w/}
    #pp url_detail
    detail_hash             = Hash.new
    #puts "URL Details"
    idx = 0
    url_detail.each do |each_detail|
      if (each_detail =~ /Filing Date$/)
        detail_hash["Filing_Date"] = url_detail[idx+1]
      end
      if (each_detail =~ /Period of Report/)
        detail_hash["filing_period"] = url_detail[idx+1]
      end
      idx = idx + 1
    end

    if(detail_hash["Filing_Date"].nil?)
      detail_hash["Filing_Date"] = "N/A"
    end

    if(detail_hash["filing_period"].nil?)
      detail_hash["filing_period"] = detail_hash["Filing_Date"]
    end

    #detail_hash             = Hash[*url_detail.flatten(1)]
    #pp detail_hash

    page.css('table[@class = "tableFile"][@summary="Document Format Files"]').each do |node|
      all_txt = node.css('tr').children.text.to_s
      if all_txt.match('10-K')
        detail_hash["fil_type"] = "10-K"
      elsif all_txt.match('10-Q')
        detail_hash["fil_type"] = "10-Q"
      else
        detail_hash["fil_type"] = all_txt
      end
    end
    detail_hash["cmp_ticker"]  = page.css('table[@class = "tableFile"][@summary="Data Files" ] > tr[2] > td[3]').children.text.strip.split("-").first
    cmp_name_cik  = page.css('div[@class = "companyInfo"] > span[@class ="companyName"]').children.text.split("\n")
    detail_hash["cmp_name"]    = cmp_name_cik[0].gsub(/\(Filer\)/,'').gsub(/\,/,' ').gsub(/\s+/,'_').strip
    cmp_cik                    = cmp_name_cik[1].gsub(/CIK:/,'').gsub(/\s+/,'').gsub(/\(seeallcompanyfilings\)/,'')
    cmp_cik                    = cmp_cik.gsub(/[a-zA-z\/\,\)\(]+/,'')
    detail_hash["cmp_cik"]     = cmp_cik
    detail_hash["cmp_url"]     = url
    #pp page.css('table[@class = "tableFile"][@summary="Data Files" ] > tr[2] > td[3]')

    xbrl_type = String.new()
    next if page.at_css('a[@id="interactiveDataBtn"]').nil?
    #puts "filing has XBRL data"
    filings_xbrl << detail_hash

    #Opening a file , looping through it and writing at the end seems too much work.... Just store in memory and dump at once?
    #FIXME?
    #puts "Writing into file: #{xbrl_links_file}"
    File.open(xbrl_links_file, 'w') do |out|
      YAML.dump(filings_xbrl,out)
    end
  end
end


def parse_edgar(cmp_detail = {})
  cpy_detail = Hash.new {|h,k| h[k] = Hash.new(&h.default_proc)}
  url        = cmp_detail["cmp_url"]
  cmp_ticker = cmp_detail["cmp_ticker"]
  cmp_cik    = cmp_detail["cmp_cik"]
  puts "Invoking parse_edgar routine for #{cmp_ticker} @ #{url}"
  FileUtils.mkdir_p(DOWNLOAD_PATH) if !File.exists?(DOWNLOAD_PATH)
  download_dir = DOWNLOAD_PATH + url.split("/")[-2]
  if !File.exists?(download_dir)
    #puts "For ticker #{cmp_ticker},downloading Filing from #{url}"
    dl = Xbrlware::Edgar::HTMLFeedDownloader.new()
    dl.download(url, download_dir)
  end

  instance_file = Xbrlware.file_grep(download_dir)["ins"]
  if instance_file.nil?
    puts "Didn't find instance schema for #{cmp_cik} ticker #{cmp_ticker}"
    return
  end
  
  begin
    instance = Xbrlware.ins(instance_file)
  rescue REXML::ParseException => e
    puts "REXML::ParseException ,skipped this filing #{cmp_cik} .... #{cmp_ticker}"
    puts "Skipping this filing"
    return
  end
    
  taxonomy = instance.taxonomy
  taxonomy.init_all_lb
  #rescue REXML::ParseException => e
  #  begin
  #    puts "XML Error #{e.error}"
  #    system 'rm -rf /home/scriptssalvi/download/*'
  #    parse_edgar(cmp_detail)
  #    puts "Printing filing details for #{cmp_detail["cmp_cik"]}"
  #  end

  cpy_detail[cmp_cik.to_sym]["analyst_est"] = SecEdgar::Marketwatch.parse_ticker(cmp_ticker)
  sdate = Date.xmlschema($todays_date)
  edate = sdate + 1
  shrp = Quandl::DailyData.scrape_data(cmp_ticker,sdate.to_s,edate.to_s)
  if(shrp.nil?)
    sdate = sdate - 2
    edate = sdate + 1
    shrp = Quandl::DailyData.scrape_data(cmp_ticker,sdate.to_s,edate.to_s)
  end
  #FIXME
  #if !quote.nil?
  #  mcap =  quote.marketCap
  #  div  =  quote.dividendPerShare
  #else
    mcap = "N/A"
    div  = "N/A"
  #end
  cpy_detail[cmp_cik.to_sym]["yahoo"][":MCAP"] = mcap
  cpy_detail[cmp_cik.to_sym]["yahoo"][":DIV"]  = div
  cpy_detail[cmp_cik.to_sym]["yahoo"][":SHRP"]  = shrp

  cpy_detail[cmp_cik.to_sym]["filing"][":FIL_DATE"]       = cmp_detail["Filing_Date"]
  cpy_detail[cmp_cik.to_sym]["filing"][":FIL_CMP_TICKER"] = cmp_ticker
  cpy_detail[cmp_cik.to_sym]["filing"][":FIL_CMP_NAME"]   = cmp_detail["cmp_name"]
  cpy_detail[cmp_cik.to_sym]["filing"][":FIL_CMP_PERIOD"] = cmp_detail["filing_period"]

  @instance = Xbrlware.ins(instance_file)
  @taxonomy = @instance.taxonomy
  @taxonomy.init_all_lb

  assets              = @instance.item("Assets")
  sth_eqs             = @instance.item("StockholdersEquity")

  #Maintain the order of search.
  revs_string = ["Revenues","SalesRevenueNet","SalesRevenueGoodsNet","SalesRevenueServicesNet","OilAndGasSalesRevenue","ContractsRevenue","InterestAndDividendIncomeOperating","AdvertisingRevenue","FoodAndBeverageRevenue"]
  revs = items_with_segment_nil(@instance,revs_string)

  stks_string = ["WeightedAverageNumberOfSharesOutstandingDiluted","WeightedAverageNumberOfDilutedSharesOutstanding","WeightedAverageNumberOfSharesOutstandingBasic","WeightedAverageNumberOfBasicSharesOutstanding","CommonStockSharesOutstanding","CommonStockSharesIssued","WeightedAverageLimitedPartnershipUnitsOutstanding"]

  stk_outs = items_with_segment_nil(@instance,stks_string)

  liabs_string = ["Liabilities","LiabilitiesNoncurrent","LiabilitiesCurrent","LongTermDebtNoncurrent"]
  liabs  = items_with_segment_nil(@instance,liabs_string)

  eps_string = ["EarningsPerShareDiluted","EarningsPerShareBasicAndDiluted","EarningsPerShareBasic"]
  item_eps = items_with_segment_nil(@instance,eps_string)


  if !assets.empty?
    assets.each do |asset|
      date = asset.context.period.value.to_date
      if (asset.def["id"] == "us-gaap_Assets" && asset.def["type"] == "xbrli:monetaryItemType")
        if asset.context.entity.segment.nil?
          period = Date.today - date
          period = period.to_s.split("\/").first
          #$cmp_assets[cmp_cik.to_sym][date.to_s] =  asset.value
          cpy_detail[cmp_cik.to_sym]["assets"][date.to_s] = asset.value
        end
      end
    end
  end

  if !revs.empty?
    revs.each do |rev_each|
      sdate =   rev_each.context.period.value["start_date"].to_date
      edate =   rev_each.context.period.value["end_date"].to_date
      period =  edate - sdate
      period = period.to_s.split("\/").first
      period = period.to_i
      if rev_each.context.entity.segment.nil?
        revs_append = revs_string.map {|string| "us-gaap_#{string}" }
        revs_append.each do |rev_append|
          if ((rev_each.def["id"] == rev_append.to_s) && (rev_each.def["type"] == "xbrli:monetaryItemType"))
            if period < 100
              period = ":3_MTHS"
            elsif (period > 100 && period < 350)
              period = ":6_MTHS"
            else
              period = ":12_MTHS"
            end
            #$cmp_revs[cmp_cik.to_sym][edate.to_s][period] = rev_each.value.to_f
            cpy_detail[cmp_cik.to_sym]["revenue"][edate.to_s][period] = rev_each.value.to_f
          end
        end
      else
        puts "ERROR: Didn't find revenue taxonomy entry for #{cmp_cik}"
      end
    end
  end

  if !liabs.empty?
    liabs.each do |liab|
      date = liab.context.period.value.to_date
      if ( ( (liab.def["id"] == "us-gaap_Liabilities") || (liab.def["id"] == "us-gaap_LiabilitiesNoncurrent")) && liab.def["type"] == "xbrli:monetaryItemType")
        if liab.context.entity.segment.nil?
          period = Date.today - date
          period = period.to_s.split("\/").first
          #$cmp_liabs[cmp_cik.to_sym][date.to_s] =  liab.value
          cpy_detail[cmp_cik.to_sym]["liabs"][date.to_s] = liab.value
        end
      end
    end
  else
    puts "Error: Didn't find liab taxonomy entry for #{cmp_cik}"
  end

  #I want to capture the total liabilities which are reported in LIabilities or LiabilitiesNoncurrent,sometimes those string are not listed instead,
  #liabilitiesCurrent are listed and Liabilieslongterm are listed, these are also listed but form a smaller number.
  #If after going through LIAB if hash is still empty look for other strings.
  if (!liabs.empty? &&  cpy_detail[cmp_cik.to_sym]["liabs"].nil?)
    liabs.each do |liab|
      date = liab.context.period.value.to_date
      if ( ( (liab.def["id"] == "us-gaap_LiabilitiesCurrent") || (liab.def["id"] == "us-gaap_LongTermDebtNoncurrent")) && liab.def["type"] == "xbrli:monetaryItemType")
        if liab.context.entity.segment.nil?
          period = Date.today - date
          period = period.to_s.split("\/").first
          #$cmp_liabs[cmp_cik.to_sym][date.to_s] =  liab.value
          cpy_detail[cmp_cik.to_sym]["liabs"][date.to_s] = liab.value
        end
      end
    end
  end

  if !sth_eqs.empty?
    sth_eqs.each do |sth_eq|
      date = sth_eq.context.period.value.to_date
      if (sth_eq.def["id"] == "us-gaap_StockholdersEquity" && sth_eq.def["type"] == "xbrli:monetaryItemType")
        if sth_eq.context.entity.segment.nil?
          period = Date.today - date
          period = period.to_s.split("\/").first
          #$cmp_sth_eqs[cmp_cik.to_sym][date.to_s] =  sth_eq.value
          cpy_detail[cmp_cik.to_sym]["equity"][date.to_s] = sth_eq.value
        end
      end
    end
  else
    puts "Error: Didn't find stock_holder_eq taxonomy entry for #{cmp_cik}"
  end

  if !stk_outs.empty?
    date = Date.today
    stk_outs.each do |stk_out|
      stks_append = stks_string.map {|string| "us-gaap_#{string}"}
      stks_append.each do |stk_append |
        if ( (stk_out.def["type"] == "xbrli:sharesItemType") && ( (stk_out.def["id"] == stk_append.to_s) ))
          if stk_append.to_s =~ /CommonStockShare/
            date = stk_out.context.period.value.to_date
          else
            date = stk_out.context.period.value["end_date"].to_date
          end
          break
        end
      end
      period = Date.today - date
      period = period.to_s.split("\/").first
      #$cmp_stk_outs[cmp_cik.to_sym][date.to_s] =  stk_out.value
      cpy_detail[cmp_cik.to_sym]["num_stocks"][date.to_s] = stk_out.value
    end
  else
    puts "Error: Didn't find Outstanding Stock entry for #{cmp_cik}"
  end

  if item_eps.nil?
    puts "Filing has no EPS entry"
  else
    if !item_eps.empty?
      item_eps.each do |eps_each|
        sdate =   eps_each.context.period.value["start_date"].to_date
        edate =   eps_each.context.period.value["end_date"].to_date
        period =  edate - sdate
        period = period.to_s.split("\/").first
        period = period.to_i
        if period < 100
          period = ":3_MTHS"
        elsif (period > 100 && period < 350)
          #next
          period = ":6_MTHS"
        else
          period = ":12_MTHS"
        end
        #$cmp_eps[cmp_cik.to_sym][edate.to_s][period] = eps_each.value.to_f
        cpy_detail[cmp_cik.to_sym]["eps"][edate.to_s][period] = eps_each.value.to_f
      end
    end
  end
  #pp $cmp_assets
  return cpy_detail
end

def print_edgar(cmp_detail = {},parse_detail = {})
  #puts "parse_detail"
  #pp parse_detail
  cmp_cik    = cmp_detail["cmp_cik"]
  cmp_ass_info = Hash.new{ |h,k| h[k] = Hash.new(&h.default_proc) }
  cmp_rev_info = Hash.new{ |h,k| h[k] = Hash.new(&h.default_proc) }
  cmp_liab_info = Hash.new{ |h,k| h[k] = Hash.new(&h.default_proc) }
  cmp_sthe_info = Hash.new{ |h,k| h[k] = Hash.new(&h.default_proc) }
  cmp_stkout_info = Hash.new{ |h,k| h[k] = Hash.new(&h.default_proc) }
  cmp_eps_info = Hash.new{ |h,k| h[k] = Hash.new(&h.default_proc) }
  cmp_assets = Hash.new{ |h,k| h[k] = Hash.new(&h.default_proc) }
  cmp_revs    = Hash.new{ |h,k| h[k] = Hash.new(&h.default_proc) }
  cmp_liabs = Hash.new{ |h,k| h[k] = Hash.new(&h.default_proc) }
  cmp_sth_eqs = Hash.new{ |h,k| h[k] = Hash.new(&h.default_proc) }
  cmp_stk_outs = Hash.new{ |h,k| h[k] = Hash.new(&h.default_proc) }
  cmp_eps    = Hash.new{ |h,k| h[k] = Hash.new(&h.default_proc) }
  cmp_yahoo  = Hash.new{ |h,k| h[k] = Hash.new(&h.default_proc) }
  cmp_fil    = Hash.new{ |h,k| h[k] = Hash.new(&h.default_proc) }
  anly_est_hoa = Hash.new{ |h,k| h[k] = Hash.new(&h.default_proc) }

  cmp_assets = parse_detail[cmp_cik.to_sym]["assets"]
  cmp_revs   = parse_detail[cmp_cik.to_sym]["revenue"]
  cmp_liabs  = parse_detail[cmp_cik.to_sym]["liabs"]
  cmp_sth_eqs = parse_detail[cmp_cik.to_sym]["equity"]
  cmp_stk_outs = parse_detail[cmp_cik.to_sym]["num_stocks"]
  cmp_eps      = parse_detail[cmp_cik.to_sym]["eps"]
  cmp_yahoo    = parse_detail[cmp_cik.to_sym]["yahoo"]
  cmp_fil      = parse_detail[cmp_cik.to_sym]["filing"]
  anly_est_hoa = parse_detail[cmp_cik.to_sym]["analyst_est"]

  cmp_ass_info[":TV"]  = "N/A"
  cmp_ass_info[":LV"]  = "N/A"
  cmp_ass_info["%CHG"] = "N/A"
  unless cmp_assets.nil?
    periods = cmp_assets.keys.sort.last(2)
    cmp_ass_info[":TP"] = periods[1]
    cmp_ass_info[":LP"] = periods[0]
    this_value = cmp_assets[periods[1]]
    last_value = cmp_assets[periods[0]]
    #Sometimes there are no previous assets listed.
    if (  (last_value.to_s =~ /\{/) || (last_value.to_f == 0.0))
      last_value = "N/A"
    end
    if this_value.to_s =~ /\{/
      this_value = "N/A"
    end

    cmp_ass_info[":TV"]  = this_value
    cmp_ass_info[":LV"]  = last_value

    if ( (last_value.to_s == "N/A") || (this_value.to_s == "N/A") || (last_value.to_f == 0.0))
      cmp_ass_info["%CHG"] = "N/A"
    else
      cmp_ass_info["%CHG"] = (100*( this_value.to_i - last_value.to_i)/ last_value.to_i.abs).to_f.round(2)
    end
  end

  unless cmp_liabs.nil?
    periods = cmp_liabs.keys.sort.last(2)
    cmp_liab_info[":TP"] = periods[1]
    cmp_liab_info[":LP"] = periods[0]
    this_value = cmp_liabs[periods[1]]
    last_value = cmp_liabs[periods[0]]
    #Sometimes there are no previous assets listed.
    if last_value.to_s =~ /\{/
      last_value = "N/A"
    end
    if this_value.to_s =~ /\{/
      this_value = "N/A"
    end

    cmp_liab_info[":TV"]  = this_value
    cmp_liab_info[":LV"]  = last_value
    if ( (last_value.to_s == "N/A") ||  (this_value.to_s == "N/A") || (last_value.to_f == 0.0) )
      cmp_liab_info["%CHG"] = "N/A"
    else
      cmp_liab_info["%CHG"] = (100*( this_value.to_i - last_value.to_i)/ last_value.to_i.abs).to_f.round(2)
    end
  end

  #Start with default value N/A
  cmp_rev_info[":TV"]   = "N/A"
  cmp_rev_info[":LV"]   = "N/A"
  cmp_rev_info[":%CHG"] = "N/A"
  unless cmp_revs.nil?
    periods_all = cmp_revs.keys.sort
    periods = cmp_revs.keys.sort.last(2)
    cmp_rev_info[":TP"] = periods[1]
    cmp_rev_info[":LP"] = periods[0]
    if cmp_revs[periods[1]][":3_MTHS"].to_s !~ /\{/
      this_rev = cmp_revs[periods[1]][":3_MTHS"]
      last_rev = cmp_revs[periods[0]][":3_MTHS"]
      if last_rev.blank?
        puts "In some cases, the period[1] doesnot have entry for 3_MTHS REV....See if period_all[0] has it, for #{cmp_cik}"
        last_revs = "N/A"
        if cmp_revs[periods_all[1]][":6_MTHS"].to_s !~ /\{/
          last_rev = cmp_revs[periods_all[1]][":6_MTHS"]
        elsif cmp_revs[periods_all[0]][":6_MTHS"].to_s !~ /\{/
          last_rev = cmp_revs[periods_all[0]][":6_MTHS"]
        else
          puts "SOMETHING FUCKED UP WITH REV ENTRY from FILING ; #{cmp_cik}"
          last_rev = "N/A"
        end
      end
      if ( (last_rev.to_s == "N/A") || (this_rev.to_s == "N/A") )
        rev_chg = "N/A"
      else
        rev_chg  = (100*((this_rev.to_f - last_rev.to_f)/(last_rev.to_f).abs)).to_f.round(2)
      end

      cmp_rev_info[":TV"] = this_rev
      cmp_rev_info[":LV"] = last_rev
      cmp_rev_info[":%CHG"] = rev_chg
    elsif cmp_revs[periods[1]][":12_MTHS"].to_s !~ /\{/
      this_rev = cmp_revs[periods[1]][":12_MTHS"]
      last_rev = cmp_revs[periods[0]][":12_MTHS"]

      periods_all = cmp_revs.keys.sort
      if last_rev.blank?
        puts "In some cases, the period[1] doesnot have entry for 12_MTHS REV....See if period_all[0] has it"
        if cmp_revs[periods_all[0]][":12_MTHS"].to_s !~ /\{/
          last_rev = cmp_revs[periods_all[0]][":12_MTHS"]
        else
          if cmp_revs[periods_all[1]][":6_MTHS"].to_s !~ /\{/
            last_rev = cmp_revs[periods_all[1]][":6_MTHS"]
          elsif cmp_revs[periods_all[0]][":6_MTHS"].to_s !~ /\{/
            last_rev = cmp_revs[periods_all[0]][":6_MTHS"]
          else
            puts "SOMETHING FUCKED UP WITH REV ENTRY from FILING ; #{cmp_cik}"
            last_rev = "N/A"
          end
        end
      end

      if last_rev.to_s == "N/A"
        rev_chg = "N/A"
      else
        rev_chg  = (100*((this_rev.to_f - last_rev.to_f)/last_rev.to_f.abs)).to_f.round(2)
      end

      cmp_rev_info[":TV"] = this_rev
      cmp_rev_info[":LV"] = last_rev
      cmp_rev_info[":%CHG"] = rev_chg
    else
      puts "Filing without REV?"
      cmp_rev_info[":TV"]   = "N/A"
      cmp_rev_info[":LV"]   = "N/A"
      cmp_rev_info[":%CHG"] = "N/A"
    end
  end

  cmp_sthe_info[":TV"] = "N/A"
  unless cmp_sth_eqs.nil?
    periods = cmp_sth_eqs.keys.sort.last(2)
    cmp_sthe_info[":TP"] = periods[1]
    cmp_sthe_info[":LP"] = periods[0]
    this_value = cmp_sthe_info[periods[1]]
    last_value = cmp_sthe_info[periods[0]]
    #Sometimes there are no previous assets listed.
    if ( (last_value.to_s =~ /\{/) || (last_value.to_f == 0.0) )
      last_value = "N/A"
    end
    if this_value.to_s =~ /\{/
      this_value = "N/A"
    end

    cmp_sthe_info[":TV"]  = this_value
    cmp_sthe_info[":LV"]  = last_value
    if ( (last_value.to_s == "N/A") || (last_value.to_s == "N/A") || (last_value.to_f == 0.0))
      cmp_sthe_info["%CHG"] = "N/A"
    else
      cmp_sthe_info["%CHG"] = (100*( this_value.to_i - last_value.to_i)/last_value.to_i.abs).to_f.round(2)
    end
  end

  cmp_stkout_info[":TV"]  = "N/A"
  cmp_stkout_info["%CHG"] = "N/A"
  unless cmp_stk_outs.nil?
    periods = cmp_stk_outs.keys.sort.last(2)
    cmp_stkout_info[":TP"] = periods[1]
    cmp_stkout_info[":LP"] = periods[0]
    this_value = cmp_stk_outs[periods[1]]
    last_value = cmp_stk_outs[periods[0]]
    cmp_stkout_info[":TV"]  = this_value
    cmp_stkout_info[":LV"]  = last_value
    if ( (this_value.to_s =~ /\{/) || (this_value.to_s =~ /\{/) )
      cmp_stkout_info["%CHG"] = "N/A"
      if (this_value.to_s =~ /\{/)
        cmp_stkout_info[":TV"]  = "N/A"
      end
    elsif ( ( last_value.to_s == "N/A") || (this_value.to_s == "N/A") || ( last_value.to_f == 0.0 ))
      cmp_stkout_info["%CHG"] = "N/A"
    else
      cmp_stkout_info["%CHG"] = (100*( this_value.to_i - last_value.to_i)/ last_value.to_f.abs).to_f.round(2)
    end
  end

  cmp_eps_info[":TV"]  = "N/A"
  cmp_eps_info[":LV"]   = "N/A"
  cmp_eps_info[":%CHG"]  = "N/A"
  cmp_eps_info[":AE"]  = "N/A"
  cmp_eps_info[":PT"]  = "N/A"
  unless cmp_eps.nil?
    periods_all = cmp_eps.keys.sort
    periods = cmp_eps.keys.sort.last(2)
    cmp_eps_info[":TP"] = periods[1]
    cmp_eps_info[":LP"] = periods[0]
    if cmp_eps[periods[1]][":3_MTHS"].to_s !~ /\{/
      this_eps = cmp_eps[periods[1]][":3_MTHS"]
      last_eps = cmp_eps[periods[0]][":3_MTHS"]
      if last_eps.blank?
        puts "In some cases, the period[1] doesnot have entry for 3_MTHS EPS....See if period_all[0] has it"
        if cmp_eps[periods_all[0]][":3_MTHS"].to_s !~ /\{/
          last_eps = cmp_eps[periods_all[0]][":3_MTHS"]
        else
          if cmp_eps[periods_all[1]][":6_MTHS"].to_s !~ /\{/
            last_eps = cmp_eps[periods_all[1]][":6_MTHS"]
          elsif cmp_eps[periods_all[0]][":6_MTHS"].to_s !~ /\{/
            last_eps = cmp_eps[periods_all[0]][":6_MTHS"]
          else
            puts "SOMETHING FUCKED UP WITH EPS ENTRY from FILING ; #{cmp_cik}"
            last_eps = "N/A"
          end
        end
      end

      if ( (last_eps.to_s == "N/A") || (this_eps.to_s == "N/A"))
        eps_chg = "N/A"
      else
        eps_chg  = (100*((this_eps.to_f - last_eps.to_f)/(last_eps.to_f).abs)).to_f.round(2)
      end

      cmp_eps_info[":TV"] = this_eps
      cmp_eps_info[":LV"] = last_eps
      cmp_eps_info[":%CHG"] = eps_chg
      cmp_eps_info[":AE"]   = anly_est_hoa[:"QMeanEst"]
      cmp_eps_info[":PT"]   = anly_est_hoa[:"TargPrice"]
    elsif cmp_eps[periods[1]][":12_MTHS"].to_s !~ /\{/
      this_eps = cmp_eps[periods[1]][":12_MTHS"]
      last_eps = cmp_eps[periods[0]][":12_MTHS"]

      periods_all = cmp_eps.keys.sort
      if last_eps.blank?
        puts "In some cases, the period[1] doesnot have entry for 12_MTHS EPS....See if period_all[0] has it"
        if cmp_eps[periods_all[0]][":12_MTHS"].to_s !~ /\{/
          last_eps = cmp_eps[periods_all[0]][":12_MTHS"]
        else
          if cmp_eps[periods_all[1]][":6_MTHS"].to_s !~ /\{/
            last_eps = cmp_eps[periods_all[1]][":6_MTHS"]
          elsif cmp_eps[periods_all[0]][":6_MTHS"].to_s !~ /\{/
            last_eps = cmp_eps[periods_all[0]][":6_MTHS"]
          else
            puts "SOMETHING FUCKED UP WITH EPS ENTRY from FILING ; #{cmp_cik}"
            last_eps = "N/A"
          end
        end
      end

      if ( (last_eps.to_s == "N/A") || (this_eps.to_s == "N/A"))
        eps_chg = "N/A"
      else
        eps_chg  = (100*((this_eps.to_f - last_eps.to_f)/last_eps.to_f.abs)).to_f.round(2)
      end

      cmp_eps_info[":TV"] = this_eps
      cmp_eps_info[":LV"] = last_eps
      cmp_eps_info[":%CHG"] = eps_chg
      cmp_eps_info[":AE"]   = anly_est_hoa[:"YMeanEst"]
      cmp_eps_info[":PT"]   = anly_est_hoa[:"TargPrice"] 
    else
      puts "Filing without EPS?"
      cmp_eps_info[":TV"]   = "N/A"
      cmp_eps_info[":LV"]   = "N/A"
      cmp_eps_info[":%CHG"] = "N/A"
      cmp_eps_info[":AE"]   = "N/A"
      cmp_eps_info[":PT"]   = anly_est_hoa[:"TargPrice"] 
    end
  end

  #pp cmp_assets
  #pp cmp_liabs
  #puts "END: #{cmp_cik}"
  this_eps   = cmp_eps_info[":TV"]
  last_eps   = cmp_eps_info[":LV"]
  eps_chg    = cmp_eps_info[":%CHG"]
  anly_est   = cmp_eps_info[":AE"]
  anly_price = cmp_eps_info[":PT"]
  mcap       = cmp_yahoo[":MCAP"]
  shrp       = cmp_yahoo[":SHRP"]
  div        = cmp_yahoo[":DIV"]
  fil_date   = cmp_fil[":FIL_DATE"]
  cmp_name   = cmp_fil[":FIL_CMP_NAME"]
  cmp_ticker = cmp_fil[":FIL_CMP_TICKER"]
  this_period = cmp_fil[":FIL_CMP_PERIOD"]
  cur_ass    = cmp_ass_info[":TV"]
  prev_ass   = cmp_ass_info[":LV"]
  pct_chg_ass = cmp_ass_info["%CHG"]
  cur_liab   = cmp_liab_info[":TV"]
  prev_liab  = cmp_liab_info[":LV"]
  pct_chg_liab = cmp_liab_info["%CHG"]
  cur_stock_eq = cmp_sthe_info[":TV"]
  cur_stock_out = cmp_stkout_info[":TV"]
  pct_stk_chg   = cmp_stkout_info["%CHG"]
  cur_rev       = cmp_rev_info[":TV"]
  pct_rev_chg   = cmp_rev_info[":%CHG"]

  if ( (anly_est.to_s == "N/A") || ( anly_est.to_s.match(/\{/)))
    anly_chg = "N/A"
  else
    anly_chg   = (100*(this_eps.to_f - anly_est.to_f)/anly_est.to_f.abs).round(2)
  end

  if !mcap.to_s.match(/\{/)
    if str = mcap.match(/([0-9.]+)(K|M|B)/i)
      mcap_num,mcap_wt = str.captures

      if mcap_wt =~ /K/
        mcap_mil = mcap_num.to_i/1000
        mcap_val = mcap_val.to_i * 1000
      elsif mcap_wt =~ /M/
        mcap_mil = mcap_num.to_i
        mcap_val = mcap_num.to_i * 1000 * 1000
      elsif mcap_wt =~ /B/
        mcap_mil = mcap_num.to_i * 1000
        mcap_val = mcap_num.to_i * 1000 * 1000 * 1000
      else
        mcap_mil = mcap_num.to_i
        mcap_val = mcap_num.to_i
      end
    end
  else
    puts "ERROR MCAP.....is not found"
    mcap_val = "N/A"
    mcap_mil = "N/A"
  end

  #puts "cur_ass  #{cur_ass}"
  #puts "cur_liab #{cur_liab}"

  if (cur_liab.to_s  =~/\{/ || cur_ass.to_s  =~/\{/)
    ass_liab_ratio = "N/A"
  else
    ass_liab_ratio = (cur_ass.to_f/cur_liab.to_f).round(2)
  end

  if (cur_stock_eq.to_s !~ /\{/)
    sthe = (cur_stock_eq.to_f).round(2)
  else
    if ( (cur_stock_eq.to_s =~ /\{/) && (cur_liab.to_s !~ /\{/))
      cur_stock_eq = cur_ass.to_f - cur_liab.to_f
      sthe = (cur_stock_eq.to_f).round(2)
    else
      sthe = "N/A"
    end
  end

  #pp cmp_ass_info
  string = cmp_name.to_s + "," + cmp_ticker.to_s + "," + cmp_cik.to_s + "," +  fil_date.to_s + "," + this_period.to_s + "," + cur_ass.to_s  + "," + pct_chg_ass.to_s + "," + cur_liab.to_s  + "," + pct_chg_liab.to_s + "," + this_eps.to_s  +  "," + eps_chg.to_s   + "," + anly_est.to_s  + "," + anly_chg.to_s +  "," + anly_price.to_s +  "," + ass_liab_ratio.to_s  +  "," + sthe.to_s + "," + shrp.to_s + "," + div.to_s +  "," + mcap_mil.to_s + "M," + cur_stock_out.to_s + "," + pct_stk_chg.to_s + "," + cur_rev.to_s + "," + pct_rev_chg.to_s + "\n"

  plot_string = cmp_ticker.to_s + "\t" + eps_chg.to_s + "\t" + pct_rev_chg.to_s
  $file_all_data.puts(string)
  #File.open($all_data_csv, 'a') {|f| f.puts(string)}
  #File.open($last_data_csv, 'a') {|f| f.puts(string)}
  #File.open($all_plot_txt, 'a') {|f| f.puts(plot_string)}
end

####MAIN
if File.exists?(xbrl_links_file)
  puts "Today's XBRL links are available, parsing file #{xbrl_links_file}"
  cmp_details = YAML.load_file(xbrl_links_file)
else
  puts "Didn't find file: #{xbrl_links_file} "
  puts "Extracting XBRL links from todays filings."
  func_xbrl_links(xbrl_links_file)
  puts "Extracted Today's filings , loading file #{xbrl_links_file} "
  cmp_details = YAML.load_file(xbrl_links_file)

end

#pp cmp_details
string = "cmp_name,cmp_ticker,cmp_cik,File_Date,This_period,Curr_Ass,Chg_Ass%,Curr_Liab,Chg_liab%,C_EPS,Chg_EPS%,ANL_EST,ANL_EPS%,ANL_PT,ASS/LIAB,STHE,SHRP,DIV,MCAP,STK_OUT,%Chg_STK,REV,%CHG_REV"

rerun = 0
last_line = ""
last_cik = ""
if File.exists?($all_data_csv)
    File.foreach($all_data_csv) do |line|
    last_line = line
  end
  rerun = 1
  puts "CSV file already exists for #{$todays_date}"
  last_cik = last_line.match(".*?\,.*?\,(.*?)\,")
  $file_all_data = File.open($all_data_csv, 'a')
else
  $file_all_data = File.open($all_data_csv, 'a')
  $file_all_data.puts(string)
end

cmp_details.each do |cmp_detail|
  if(rerun == 1)
    #puts "Checking for last CIK: #{last_cik[1]} with #{cmp_detail["cmp_cik"]}"
    last_entry_found = last_cik[1].match(cmp_detail["cmp_cik"])
    next if last_entry_found.nil?
    rerun = 0
    next
  end
  if(cmp_detail["fil_type"].to_s == "10-Q" || cmp_detail["fil_type"].to_s == "10-K")
    begin
      each_cpy_detail = Hash.new{ |h,k| h[k] = Hash.new(&h.default_proc) }
      each_cpy_detail = parse_edgar(cmp_detail)
      next if each_cpy_detail.nil?

      #pp each_cpy_detail
      print_edgar(cmp_detail,each_cpy_detail)
    end
  end
end
$file_all_data.close
system("sudo rm -rf #{DOWNLOAD_PATH_DATE}")

#File.open($last_data_csv, 'w') {|f| f.puts(string) }
#plot_string = "cmp_ticker  C_EPS   C_REV"
#File.open(all_plot_txt, 'w') {|f| f.puts(plot_string)}


#`rm -rf #{DOWNLOAD_#mail = Mail.new do
#  from 'scriptssalvi@gmail.com'
#  to   'scriptssalvi@gmail.com'
#  cc   'kotinara@gmail.com,e.sema07@gmail.com'
#  subject "10/Q/k for #{$todays_date} sent on #{tdate}"
#  body "#{tdate}"
#  add_file $all_data_csv
#  #add_file $last_data_csv
#end
#mail.delivery_method :sendmail
#mail.deliver
#`rm -rf #{DOWNLOAD_PATH_DATE}`







