require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'

def clean_phone_number(phone_number)
  /^1?\d{10}$/ =~ phone_number.gsub(/[^\d]/, '') ? phone_number : 'N/A'
end

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0...5]
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')
  File.open("output/thanks_#{id}.html", 'w') { |file| file.puts(form_letter) }
end

def peak(times)
  times.group_by { |time| times.count(time) }
       .max.last.uniq.join(', ')
end

def peak_registration_hours(reg_times)
  hour_intervals = reg_times.map do |reg_time|
    [reg_time, reg_time + 3600].map { |time| time.strftime("%-I:00%p") }
                               .join(' to ')
  end
  peak(hour_intervals)
end

def peak_registration_days_of_week(reg_times)
  days_of_week = reg_times.map { |reg_time| reg_time.strftime("%A") }
  peak(days_of_week)
end

def save_cumulative_data(peak_hours, peak_days_of_week)
  data = {"hours" => peak_hours, "days of the week" => peak_days_of_week }
  Dir.mkdir('output') unless Dir.exist?('output')
  File.open("output/cumulative_data.txt", 'w') do |file|
    file.puts("\r\n")
    file.puts(data.map { |time_unit, peak| "Peak registration #{time_unit}: #{peak}"}.join("\r\n"))
  end
end

puts "Event Manager Initialized!"

template_letter = File.read('form_letter.erb')
erb_template = ERB.new(template_letter)
reg_times = []

contents = CSV.open('event_attendees.csv', headers: true, header_converters: :symbol)
contents.each do |row|
  id = row[0]
  reg_time = Time.strptime(row[:regdate], "%m/%d/%y %k:%M")
  name = row[:first_name]
  phone_number = clean_phone_number(row[:homephone])
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
  reg_times << reg_time
end

peak_hours = peak_registration_hours(reg_times)
peak_days_of_week = peak_registration_days_of_week(reg_times)
save_cumulative_data(peak_hours, peak_days_of_week)
