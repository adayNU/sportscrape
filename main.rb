require 'rest-client'
require 'nokogiri'
require 'json'

SPORTS = "baseball", "mbball", "football", "mgolf", "msoc", "mswim", "mten", "wrestling", "wbball", "wcross", "wfenc", "fhockey", "wgolf", "wlax", "wsoc", "softball", "wswim", "wten", "wvball"

BASE_URL = "http://nusports.com/schedule.aspx?path="
GOOGLE_MAPS_URL = "https://maps.googleapis.com/maps/api/distancematrix/json?units=imperial&origins=San+Francisco+CA&destinations="
STATE = "Calif."
LOCATION_COLUMN = "Location"
DATE_COLUMN = "Date"
FIFTY_MILES_IN_METERS = 80467.2

def run!
  SPORTS.each do |sport|
    # I had to modify the user agent since nusports returns
    # 404 for some strange reason (presumably to prevent
    # scraping, though a 5xx error seems more appropriate).
    response = RestClient.get("http://nusports.com/schedule.aspx?path=#{sport}", {user_agent: "go cats"})

    page = Nokogiri::HTML(response.body)

    # grab each row of the schedule table
    rows = page.css("table#ctl00_cplhMainContent_dgrdschedule tr")

    sport_name = page.css(".sports-nav-level-1-link").first.children.first.text
    header_row_text = rows.shift.children.map{|e| e.text.strip}

    location_column = header_row_text.index(LOCATION_COLUMN)
    date_column = header_row_text.index(DATE_COLUMN)

    rows.each_with_index do |game|
      location = game.children[location_column].text
      date = Date.new
      date_string = game.children[date_column].text.strip

      begin
        date = Date.strptime(date_string, "%m/%d/%Y")
      rescue
        wonky_date = date_string.split("/")
        if wonky_date.size == 3
          # Just check if it's within the current month, possible to get an event in the past.
          date = Date.new(wonky_date[2].to_i, wonky_date[0].to_i, Date.today.day + 1)
        end
        # Oh well, guess we aren't going to this game
      end

      # Only check events in CA to avoid unnecessary queries to
      # the Google Maps API
      if location.include? STATE
        resp = RestClient.get(GOOGLE_MAPS_URL + location.gsub(/[^0-9a-z ]/i, '').gsub(" ", "+"))
        distance = JSON.parse(resp.body)["rows"].first["elements"].first["distance"]["value"]
        if distance < FIFTY_MILES_IN_METERS && date > Date.today
          puts "#{date_string}: #{sport_name} - #{location}"
        end
      end
    end
  end
end

run!
