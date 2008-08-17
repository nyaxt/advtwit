require 'net/http'

module UnTinyUrl

def self.untinyurl(turl)
  turl.match(/([a-z0-9]{6})\/?$/)

  http = Net::HTTP.new('tinyurl.com', 80)
  header = http.head('/' + $1)
  return '' unless header
  header['Location']
end

end
