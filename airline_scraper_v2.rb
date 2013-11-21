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
def extract_column_airports(page, column_name)
	airport_links = []
	table_width = 0
	airport_index = 0
	#parse the table head and return the index of the "Airport" column as well as the total column count.
	page.css('table.wikitable.sortable th').each do |c|
		if c.text.eql?(column_name)
			airport_index = page.css('table.wikitable.sortable th').index(c)
			table_width = page.css('table.wikitable.sortable th').length
			break
		end
	end

	#parse the table rows
	page.css('table.wikitable.sortable tr').each do |tr|
		#for each each row, parse the columns
		tr.css('td').each do |td|
			#if the column's index modulous the width is equal it to the desired index
			if tr.css('td').index(td)%table_width == airport_index
				#retrieve the link within that column.
				td.css('a').each do |a|
					airport_links.push(a['href'].clone)
				end
			end
		end
	end
	return airport_links
end

#Takes a nokogiri object, parses it for 'table.toccolours.sortable' and returns an array of non-redlink URLs contained within the column matching the column_name.
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
	page = agent.get('http://en.wikipedia.org/wiki/Airline_codes-All')
rescue Mechanize::ResponseCodeError => e
	puts e.to_s
end

airline_code_parser = page.parser
storage = []
destination_airports = []

#find all non-red airline links in the table
airlines = extract_column_airlines(airline_code_parser, "Airline")
#iterate through those links
airlines.each do |d|
	puts d

	#Visit each airline page
	begin
	airline = agent.get('http://en.wikipedia.org' + d)
	rescue Mechanize::ResponseCodeError, StandardError => e
		puts "Error fetching airline pages: " + e.to_s
	end
	#Build the nokogiri object
	airline_parser_object = airline.parser

	#Extract the airline name from the page title by trimming off the wikipedia suffix
	airline_name = airline_parser_object.title.slice(0, airline_parser_object.title.length-35)

	#search for a main destinations article
	main_dest_page = find_main_destinations(airline_parser_object)

	if main_dest_page.empty?
		puts "Main dest not found."
		h2_index = 0
		#Search for the destinations section.
		airline_parser_object.css('div#mw-content-text h2').each do |c|
			#puts "Parsing links"
			if c.css("span.mw-headline").text.eql?"Destinations"
				
				h2_index = airline_parser_object.css('div#mw-content-text h2').index(c)
			end
		end
		#Extract the links from the located destinations section.
		if h2_index != 0
			destinations = extract_links(["h2"], h2_index, airline_parser_object)
			#For each link found, visit that page and search for an IATA code.
			#Assume that a page returning an IATA code is an airport.
			destinations.each do |d|
				begin
					#puts "Querying page: " + d
					page = agent.get('http://en.wikipedia.org' + d)
					nokogiri_page = page.parser
					#store that IATA code
					destination_airports.push(extract_iata_code(nokogiri_page))
				rescue Mechanize::ResponseCodeError, StandardError => e
					puts "Error fetching airline destination IATA codes: " + e.to_s
				end
			end
		end	
	else
		puts "Main dest found."
		begin
			airline_destination = agent.get('http://en.wikipedia.org' + main_dest_page)

			airline_destination_parser = airline_destination.parser

			airport_links = extract_column_airports(airline_destination_parser, "Airport")

			airport_links.each do |d|
				begin
					page = agent.get('http://en.wikipedia.org' + d)
					nokogiri_page = page.parser
					#store that IATA code
					destination_airports.push(extract_iata_code(nokogiri_page))
				rescue Mechanize::ResponseCodeError, StandardError => e
					puts "Error fetching airport IATA codes from main destination article: " + e.to_s
				end
			end
		rescue Mechanize::ResponseCodeError, StandardError => e
			puts "Error fetching main airline destination article: " + e.to_s
		end
	end
	#Outside of parsing individual airports
	#push a hash consisting of airline name and an array of destination airports onto the storage array.
	storage.push({name: airline_name.clone, destinations: destination_airports.clone})
	#then reset the destination airports array to empty.
	destination_airports = []

	if airlines.index(d)%50 == 0
		puts "Writing airlines#{airlines.index(d)}"
		FileUtils.mkdir_p "./seed/"
		File.open("./seed/airlines#{airlines.index(d)}.yml",'w') do |out|
		YAML.dump(storage, out)
		end
	end
end

puts "Converting final array to yaml."
FileUtils.mkdir_p "./seed/"
File.open("./seed/airlines.yml",'w') do |out|
	YAML.dump(storage, out)
end