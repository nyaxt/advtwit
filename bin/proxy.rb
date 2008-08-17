#!/usr/bin/env ruby

require 'rubygems'
require 'webrick'
require 'webrick/httpproxy'

$: << '.'
$: << './bin'
require 'advtwit'

module AdvTwit

class AdvTwitServlet < WEBrick::HTTPServlet::AbstractServlet
  SERVLETROOT = 'atw'

  def initialize(server, core)
    @core = core
  end

  def do_GET(req, res)
    if req.path =~ /^\/#{SERVLETROOT}\/statuses\/advtwit_timeline.(\w+)/
      do_timeline(req, res, $1)
    else
      res.body = req.path
    end

    res['content-type'] = 'text/plain'
  end

  def do_POST(req, res)
    if req.path =~ /^\/#{SERVLETROOT}\/statuses\/update.(\w+)/
      do_status_update(req, res, $1)
    else
      res.set_error(404)
    end
  end

  def do_timeline(req, res, format)
    query = {}
    query = parse_query(req.request_uri.query) if req.request_uri.query

    options = {}
    options[:first_update]    = query['first_update'] == 'true' if query['first_update']
    options[:score_threshold] = query['score_threshold'].to_i if query['score_threshold']
    options[:max_statuses]   = query['max_statuses'].to_i if query['max_statuses']
    options[:since]           = Time.parse(query['since'].gsub('+', ' ')) if query['since']

    if options[:first_update]
      options[:max_statuses] = 200
      options[:since]         = @core.timeline.latest_post_time(options)
    end

    result_timeline(options, res, format)
  end

  def do_status_update(req, res, format)
    query = {}
    query = parse_query(req.body) if req.body
  
    status = query['status']
    
    if status
      @core.post_status_update status
    end

    @core.update_twit

    res.body = 'status update success' # fixme
    res['content-type'] = 'text/plain'
  end

private
  def parse_query(querystr)
    querystr.split('&').inject({}) do |r, i|
      key, val = *i.split('=').map{|encoded| URI.decode(encoded)}
      r[key] = val
      r
    end
  end

  def result_timeline(options, res, format)
    case format
    when 'xml'
      res.body = 'todo'
      res['content-type'] = 'text/plain'
    when 'json'
      res.body = @core.timeline.to_json(options)
      res['content-type'] = 'text/javascript+json; charset=utf-8'
    else
      res.body = @core.timeline.to_s(options)
      res['content-type'] = 'text/plain'
    end
  end

end

class ProxyServer < WEBrick::HTTPProxyServer

  def initialize(settings, core)
    super settings

    mount('/' + AdvTwitServlet::SERVLETROOT, AdvTwitServlet, core)
  end

  def set_via(h)
    # hook-ed here to add Twitter specific settings
    h['X-Twitter-Client'] = 'advtwit'
    h['X-Twitter-Client-Version'] = 'gittrunk'
    h['X-Twitter-Client-URL'] = CLIENTXMLURL
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

end # of module AdvTwit

if __FILE__ == $0
  core = AdvTwit::App.new($advtwit_opts)

  Thread.start {
    loop do
      core.update_twit
      puts "loaded latest tweets! :-)"
      sleep 180
    end
  }

  s = AdvTwit::ProxyServer.new({
    :DocumentRoot => 'var/www',
    :Port => 8000
    }, core)

  Signal.trap('INT') do
    s.shutdown
  end

  s.start
end
