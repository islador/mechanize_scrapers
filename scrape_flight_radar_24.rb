
require 'mechanize'
require 'nokogiri'

agent = Mechanize.new

page = agent.get('http://www.flightradar24.com/data/airports/')

country_links = page.links.find_all { |l| l.attributes.parent.name == 'li'}
country = country_links[21].click

airport_links = country.links.find_all { |d| d.attributes.parent.name == 'div'}

airport = airport_links[0].click

doc = airport.parser

	storage = []
	temp_storage = {city: nil, country: nil, i_code: nil, name: nil}

	doc.css('div.lightNoise li').each do |l|
		if doc.css('div.lightNoise li').index(l) == 0
			temp_storage[:name] = l.text.slice(14, l.text.length)
			#puts temp_storage[:name]
		end
		if doc.css('div.lightNoise li').index(l) == 1
			temp_storage[:i_code] = l.text.slice(11, l.text.length)
			#puts temp_storage[:i_code]
		end
		if doc.css('div.lightNoise li').index(l) == 3
			temp_storage[:country] = l.text.slice(9, l.text.length)
			#puts temp_storage[:country]
		end
		if doc.css('div.lightNoise li').index(l) == 4
			temp_storage[:city] = l.text.slice(6, l.text.length)
			#puts temp_storage[:city]
		end
		
	end
	temp_storage2 = {city: nil, country: nil, i_code: nil, name: nil}
	storage.push(temp_storage)
	storage.push(temp_storage2)


FileUtils.mkdir_p "./seed/"
File.open("./seed/airports.yml",'w') do |out|
		YAML.dump(storage, out)
end
