require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'
puts 'EventManager Initialized.'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5,"0")[0..4]
end

def clean_phone_numbers(phone)
  number = phone.to_s.rjust(11).tr("()-.","").delete(' ')[0..9]
  number.scan(/\D/).empty? ? number : "Sorry, invalid number"
end

def parse_time(time)
  time_to_s = time.to_s.split(' ')
  hrs = time_to_s[1].split(':')[0].to_i
  hrs
end

def peak_hours(time)
  time.each_with_object(Hash.new(0)){ |m,h| h[m] += 1 }.sort_by{|k,v| v}
end

def parse_date(date)
  date_to_s = date.to_s.split(' ')[0]
  year = ("20" + date_to_s.to_s.split('/')[2])
  month = (date_to_s.to_s.split('/')[0])
  day = (date_to_s.to_s.split('/')[1])
  [year,month,day]
end

def peak_day(day)
  day_array = []
  day.each do |d|
    day_array << Date.new(d[0].to_i,d[1].to_i,d[2].to_i).wday
  end
  day_array.each_with_object(Hash.new(0)){ |m,h| h[m] += 1 }.sort_by{|k,v| v}
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    "You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials"
  end
end

def save_thank_you_letter(id,form_letter)
  Dir.mkdir("output") unless Dir.exist? "output"

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

contents = CSV.open 'event_attendees.csv', headers: true, header_converters: :symbol

template_letter = File.read "form_letter.erb"
erb_template = ERB.new template_letter

peak_time = []
best_day = []
day_hash = {
  0 => "Sunday", 1 => "Monday", 2 => "Tuesday",
  3 => "Wednesday", 4 => "Thursday", 5 => "Friday",
  6 => "Sunday"
}

contents.each do |row|
  id = row[0]

  name = row[:first_name]

  zipcode = clean_zipcode(row[:zipcode])

  phone = clean_phone_numbers(row[:homephone])

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id,form_letter)

  peak_time << parse_time(row[:regdate])
  best_day << parse_date(row[:regdate])
  # best_hour += time[0]
  # best_mins += time[1]
  # sign_ups += 1
end

time_to_use = peak_hours(peak_time)
day_of_week = peak_day(best_day)

puts "Best Day of Week: #{day_hash[day_of_week.last[0]]}"
print "Peak Times: #{time_to_use.last[0]}:00 - #{time_to_use.last[0].to_i + 1}:00\n#{time_to_use[-2][0]}:00 - #{time_to_use[-2][0].to_i + 1}:00\n"
