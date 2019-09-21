require 'open-uri'
require 'nokogiri'
require 'json'
require 'selenium-webdriver'
require 'pry'
require 'csv'

TRIPLE_REGEX = /checkBlk\('(?<value>.*)','(?<neigh>.*)','(?<contract>.*)'\)/

url = 'https://services2.hdb.gov.sg/webapp/BP13AWFlatAvail/BP13EBSFlatSearch?Town=Tampines&Flat_Type=SBF&selectedTown=Tampines&Flat=5-Room%2F3Gen&ethnic=C&ViewOption=A&Block=0&DesType=A&EthnicA=&EthnicM=&EthnicC=C&EthnicO=&numSPR=&dteBallot=201905&Neighbourhood=&Contract=&projName=&BonusFlats1=N&searchDetails=Y&brochure=true'
html = open(url)
doc = Nokogiri::HTML.parse(html)
table = doc.search('table tbody')
# puts table.search('tr').length
matched_cells = []
table.search('tr').each do |tr|
  tr.search('td').each do |td|
    div_string = td.search('div').to_s
    matched_triple = div_string.match(TRIPLE_REGEX)
    matched_cells << matched_triple.to_s
  end
end

driver = Selenium::WebDriver.for :chrome
driver.navigate.to url

def process_matched_cell(matched_cell, driver)
  driver.execute_script(matched_cell)
  block_html = driver.find_element(:tag_name, 'html').attribute("innerHTML")

  block_doc = Nokogiri::HTML.parse(block_html)
  block_rows = block_doc.search('#blockDetails .form-row')
  block = block_rows[1].children[3].children.first.to_s.strip.gsub(/[\t\n]+/,"")
  street = block_rows[1].children[7].children.first.to_s.strip.gsub(/[\t\n]+/,"")
  completion_date = block_rows[2].children[3].children.first.to_s.strip.gsub(/[\t\n]+/,"")
  delivery_date = block_rows[3].children[3].children.first.to_s.strip.gsub(/[\t\n]+/,"")
  lease_date = block_rows[4].children[3].children.first.to_s.strip.gsub(/[\t\n]+/,"")
  block_table = block_doc.search('table tbody').last
  rows = []
  block_table.search('tr').each do |tr|
    tr.search('td').each do |td|
      fonts = td.search('font')
      if fonts.length == 1
        unit_string = fonts.first.children.to_s.strip
        rows << "#{block},#{street},#{completion_date},#{delivery_date},#{lease_date},#{unit_string},,,false".split(",")
      else
        unit_string = fonts[1].children.to_s
        next if unit_string.end_with?("*")
        hover_details = block_doc.search("#\\#{unit_string}k").first
        price = hover_details.children.first.to_s.gsub(",","")
        size = hover_details.children[4].to_s
        rows << "#{block},#{street},#{completion_date},#{delivery_date},#{lease_date},#{unit_string},#{price},#{size},true".split(",")
      end
    end
  end
  rows
end

total_rows = []
matched_cells.each do |cell|
  total_rows += process_matched_cell(cell, driver)
end

CSV.open("#{Time.now}.csv", "w") do |csv|
  total_rows.each { |row| csv << row }
end
# puts block_doc
# matched_cells.each { |cell| puts cell }
# puts matched_cells.first 
# res = /'([0-9A-Z]+)','([0-9A-Z]+)','([0-9A-Z]+)'/.match(cells.first)
# puts res
# puts res.length
# puts cells.first
# puts doc

# block, street, the dates, unit, price, size, availablity
