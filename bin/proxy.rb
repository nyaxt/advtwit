#!/usr/bin/env ruby

require 'rubygems'
require 'webrick'
require 'webrick/httpproxy'

module AdvTwit

class AdvTwitServlet < WEBrick::HTTPServlet::AbstractServlet
  def initialize(server, local_path)
    super
    @local_path = local_path
  end

  def do_GET(req, res)
    if @local_path =~ /^statuses\/advtwit_timeline.(\d+)/
      res.body = $1 
    else
      res.body = "TODOTODO"
    end

    res["content-type"] = "text/plain"
  end
end

class ProxyServer < WEBrick::HTTPProxyServer
  def initialize(settings)
    super settings

    mount('/atw', AdvTwitServlet)
  end

  def proxy_service(req, res)
    if toward_twitter?(req.request_uri)
      # do_service(req, res) 
      req.request_uri.host = "localhost"
      req.request_uri.port = @config[:Port]
    end

    super(req, res)
  end

  def toward_myself?(uri)
    uri.scheme == "http" and
    uri.host == "localhost" and # fix here
    uri.port == @config[:Port]
  end

  def toward_twitter?(uri)
    uri.scheme == "http" and
    uri.host == "twitter.com" and
    uri.port == 80
  end

  def do_service(req, res)
    res.body = "gotcha!"
    res['Content-Type'] = 'text/plain'
  end

end

end

s = AdvTwit::ProxyServer.new({
  :DocumentRoot => 'var/www',
  :Port => 8000
  })

Signal.trap('INT') do
  s.shutdown
end

s.start
