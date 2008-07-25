#!/usr/bin/ruby
# advtwit: twitter client for freaks 上級者向けtwitterクライアント（笑)

$KCODE = 'u'

require 'rubygems'
require 'pit'
require 'twitter'
require 'nkf'
require 'rexml/document'

class AdvTwit
  attr_reader :opts
  
  def initialize(opts)
    @opts = opts
  end

  def twitlogin
    @twit = Twitter::Base.new(@opts[:twit_user], @opts[:twit_pass])

    # test code
    @twit.timeline(:friends).each do |s|
      puts REXML::Text::unnormalize(s.text), s.user.name
    end
  end

  def main
    twitlogin
  end

end

opts = {}
unless false #opts[:twit_user] and opts[:twit_pass]
  credentials = Pit.get("advtwit", :require => {
    "twit_user" => "twitter username/email address",
    "twit_pass" => "twitter password",
    })

  opts[:twit_user] ||= credentials["twit_user"]
  opts[:twit_pass] ||= credentials["twit_pass"]
end

app = AdvTwit.new(opts)
app.main
