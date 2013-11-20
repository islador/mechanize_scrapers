require 'mechanize'

#Requires a nokogiri object and returns an array of query strings.
def extract_links(delim_tags, index, page)
	extract_ranges = [index...index+1]
	doc = page

	extracted_links = []

	i = 0
	# Change /"html"/"body" to the correct path of the tag which contains this list
	(doc/"html"/"body"/"div").children.each do |el|


	  if (delim_tags.include? el.name)
	    i += 1
	  else
	    extract = false
	    extract_ranges.each do |cur_range|
	      if (cur_range.include? i)
	        extract = true
	        break
	      end
	    end

	    if extract

	    	el.children.each do |d|
	    		
	    		d.css("a").each do |k|

	    			#destination = agent.get('en.wikipedia.org' + k['href'])
	    			extracted_links.push(k['href'].clone)
	    		end
	    	end
	    end
	  end

	end
	return extracted_links
end

#Requires a nokogiri object and returns the first IATA code found on the page.
def extract_iata_code(page)
	page.css('th a').each do |d|
		if d['href'].eql?("/wiki/International_Air_Transport_Association_airport_code")
			return d.next_element.text
			break
		end
	end
end

#Requires a nokogiri object. Searches for and returns the first query string ending in '_destinations'. If one is not found, it returns an empty string.
def find_main_destinations(page)
	storage = ""
	page.css('div.rellink a').each do |ad|
		if ad['href'].slice(ad['href'].length-13, ad['href'].length).eql?("_destinations")

			#returns a string
			storage = storage + ad['href']
			break
		end
	end
	return storage
end

#Takes a nokogiri object, parses it for 'table.wikitable.sortable' and returns an array of URLs contained within the column matching the column_name.
def extract_column_airlines(page, column_name)
	airport_links = []
	table_width = 0
	airport_index = 0
	#parse the table head and return the index of the "Airport" column as well as the total column count.
	page.css('table.toccolours.sortable th').each do |c|
		if c.text.eql?(column_name)
			airport_index = page.css('table.toccolours.sortable th').index(c)
			table_width = page.css('table.toccolours.sortable th').length
			break
		end
	end

	#parse the table rows
	page.css('table.toccolours.sortable tr').each do |tr|
		#for each each row, parse the columns
		tr.css('td').each do |td|
			#if the column's index modulous the width is equal it to the desired index
			if tr.css('td').index(td)%table_width == airport_index
				#retrieve the link within that column.
				td.css('a').each do |a|
					if a['href'].to_s.include?("redlink=1") == false
						airport_links.push(a['href'].clone)
					end
				end
			end
		end
	end
	return airport_links
end

agent = Mechanize.new

begin
	page = agent.get('http://en.wikipedia.org/wiki/Fly_Air')
rescue Mechanize::ResponseCodeError => e
	puts e.to_s
end

airline_parser_object = page.parser
h2_index = 0
#Search for the destinations section.
airline_parser_object.css('div#mw-content-text h2').each do |c|
	#puts "Parsing links"
	if c.css("span.mw-headline").text.eql?"Destinations"
		
		h2_index = airline_parser_object.css('div#mw-content-text h2').index(c)
	end
end

destinations = extract_links(["h2"], h2_index, airline_parser_object)

destination_airports = []

destinations.each do |k|
	puts k

end

destinations.each do |d|
	begin
		puts "Querying page: " + d
		if d.slice(0, 7).eql?("http://")
			puts d
			page = agent.get(d)
		else
			puts d
			page = agent.get('http://en.wikipedia.org' + d)
		end
		nokogiri_page = page.parser
		#store that IATA code
		destination_airports.push(extract_iata_code(nokogiri_page))

		#destination_airports.each do |d|
		#	puts d
		#end
	rescue Mechanize::ResponseCodeError, StandardError => e
		puts "Error fetching airline destination IATA codes: " + e.to_s
	end
end
