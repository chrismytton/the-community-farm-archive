require 'bundler/setup'
require 'pry'
require 'scraperwiki'
require 'open-uri'
require 'digest'

res = open('https://www.thecommunityfarm.co.uk/boxes/box_display.php')
html = res.read

# Ignore the part of the html that changes on each page load.
html.gsub!(%r{Memory Start: \d+</br>Memory End: \d+</br>Memory Peak: \d+</br>Time taken: \d+\.\d+</br>}, '[removed]')

data = {
  id: Digest::SHA1.hexdigest(html),
  html: html,
  status: res.status.join(' '),
  created_at: DateTime.now.to_s,
}

ScraperWiki.save_sqlite([:id], data)

res.meta.each do |header, value|
  ScraperWiki.save_sqlite(
    [:header, :value, :data_id],
    { header: header, value: value, data_id: data[:id] },
    'headers'
  )
end
