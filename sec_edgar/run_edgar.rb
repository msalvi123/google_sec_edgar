require 'rubygems'
require 'date'

if ARGV.empty?
  puts "Need start and end data";
  return;
elsif (ARGV[0].empty? || ARGV[1].empty?)
  puts "Specify start date: YYYY-MM-DD"
  puts "Specify End date:   YYYY-MM-DD"
  return
end

start_date = Date.xmlschema(ARGV[0])
end_date   = Date.xmlschema(ARGV[1])

fh = File.open("run_edgar_sh.sh", 'w')
i = 0
start_date.upto(end_date){ |each_date|
  if (each_date.saturday? || each_date.sunday?)
    puts "Skipping for Saturday or Sunday"
    next
  end
  puts "For Date #{each_date} running sec_edgar"
  i=i+1
  #if(i%2 == 0)
    fh.write("wait \n")
  #end  
  fh.write("nohup sudo ruby daily_edgar.rb #{each_date} & \n")
}
fh.close
system("chmod 755 run_edgar_sh.sh")

