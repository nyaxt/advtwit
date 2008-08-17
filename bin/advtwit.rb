#!/usr/bin/env ruby
# advtwit: twitter client for freaks
#          上級者向けtwitterクライアント（笑)
#
# License::
#  Copyright (c) 2008, Kouhei Ueno
#  
#  All rights reserved.
#  
#  Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
#  
#      * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
#      * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
#      * Neither the name of the nyaxtstep.com nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
#  
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
#  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
#  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
#  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
#  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
#  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
#  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
#  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
#  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
#  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
#  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

CLEAR_DB = false

$KCODE = 'u'

# for loading cfg file
$: << '../etc'
$: << 'etc'

require 'rubygems'
require 'twitter'
require 'nkf'
require 'tinyurl'
require 'rexml/document'
require 'json'
require 'MeCab'
require 'sqlite3'
require 'term/ansicolor'

module AdvTwit

class Status
  TL_PUBLIC = 0
  TL_FRIENDS = 1

  attr_accessor :id, :time, :message, :source # FIXME: rename to text, created_at
  attr_accessor :username, :userimg, :userloc, :userurl, :userid, :userprotected, :nick # FIXME: rename to screen_name
  attr_accessor :in_reply_to_status_id, :in_reply_to_user_id
  attr_accessor :score, :traits, :timeline

  def initialize(hash)
    hash.each_pair do |k, v|
      instance_variable_set("@#{k}", v)
    end
    
    @score ||= 0
    @timeline ||= TL_PUBLIC
    @in_reply_to_user_id ||= "null"
    @in_reply_to_status_id ||= "null"
  end

  def to_s 
    "#{@username} (#{@nick}): #{@message} (#{@score})"
  end

  def inspect; to_s; end

  def to_json(*a)
    {
      'user' => {
         'name' => REXML::Text::normalize(@username),
         'location' => @userloc,
         'url' => REXML::Text::normalize(@userurl),
         'description' => "not available (advtwit proxy)",
         'followers_count' => 123,
         'profile_image_url' => REXML::Text::normalize(@userimg),
         'id' => @userid,
         'protected' => @userprotected,
         'screen_name' => @nick
      },
      'truncated' => false,
      'in_reply_to_status_id' => @in_reply_to_status_id,
      "source" => REXML::Text::normalize(@source),
      "created_at" => time.rfc822,
      "id" => @id,
      "favorited" => @fav?'true':'null',
      "text" => REXML::Text::normalize(@message),
      "in_reply_to_user_id" => in_reply_to_user_id,
      "score" => @score,
      "tltype" => timelinetype
    }.to_json(*a)
  end

  def is_Japanese?
    not @message.match(/[あ-んア-ン]/).nil?
  end

  def eql?(other)
    other.id == @id
  end

  def timelinetype
    case @timeline
    when TL_PUBLIC
      'public'
    when TL_FRIENDS
      'friends'
    else
      'unknown'
    end
  end

end

class Timeline
  attr_reader :dbfile
  attr_accessor :statuses

  def initialize(db)
    @db = db

    init_db
  end

  def add_status(s)
    s = Status.new(s) unless s.is_a? Status

    begin
      @db.execute('insert into timeline values(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
        s.id, s.time.to_i, s.message, s.source,
        s.username, s.userimg, s.userloc, s.userurl, s.userid, s.userprotected ? "1" : "0", s.nick,
        s.in_reply_to_status_id, s.in_reply_to_user_id,
        s.score, s.timeline
        );

      return true
    rescue SQLite3::SQLException => e
      # puts "ignoreing error: #{e.inspect}"

      return false
    end
  end

  def console_out
    @db.execute('select * from timeline where score > 80 order by time desc limit 20;').each do |row|
      status = row2status(row)
      case
      when status.score > 300
        print Term::ANSIColor::bold
        print Term::ANSIColor::red
      when status.score > 200
        print Term::ANSIColor::bold
        print Term::ANSIColor::blue
      when status.score > 105
        print Term::ANSIColor::bold
      end

      puts row2status(row).to_s
      print Term::ANSIColor::reset
    end
  end

  def to_s(options = {})
    result = ''

    for_each_status(options) do |status|
      result << status.to_s << "\n"
    end

    result
  end

  def to_json(options = {})
    result = '['
    
    first = true
    for_each_status(options) do |status|
      if first
        first = false
      else
        result << ','
      end
        
      result << status.to_json
    end

    result << ']'
  end

  def latest_post_time(options = {})
    options = {:score_threshold => 80, :max_statuses => 20, :since => nil}.merge(options)

    @db.execute('select time from timeline where score > ? order by time desc limit 1 offset ?;', options[:score_threshold], options[:max_statuses]) do |row|
      return row[0].to_i
    end
  end

private
  def init_db
    begin
      @db.execute('drop table timeline') if CLEAR_DB
    rescue SQLite3::SQLException => e
    end

    begin
      @db.execute <<END
      create table timeline (
        id INTEGER UNIQUE,
        time INTEGER,
        text TEXT,
        source TEXT,
        
        username TEXT,
        userimg TEXT,
        userloc TEXT,
        userurl TEXT,
        userid INTEGER,
        userprotected INTEGER,
        screen_name TEXT,
        
        in_reply_to_status_id INTEGER,
        in_reply_to_user_id INTEGER,
        
        score INTEGER,
        timeline INTEGER
      );
END
      puts "new table 'timeline' has been created"
    rescue SQLite3::SQLException => e
      # table already existed
    end
  end

  def row2status(row)
    Status.new({
      :id => row[0].to_i,
      :time => Time.at(row[1].to_i),
      :message => row[2],
      :source => row[3],

      :username => row[4],
      :userimg => row[5],
      :userloc => row[6],
      :userurl => row[7],
      :userid => row[8].to_i,
      :userprotected => (row[9].to_i == 1),
      :nick => row[10],

      :in_reply_to_status_id => row[11].to_i,
      :in_reply_to_user_id => row[12].to_i,

      :score => row[13].to_i,
      :timeline => row[14].to_i,
      })
  end

  def for_each_status(options = {})
    options = {:score_threshold => 80, :max_statuses => 20, :since => nil}.merge(options)

    # FIXME: use SQLite3::Statement
    if options[:since]
      @db.execute('select * from timeline where score > ? and time > ? order by time asc limit ?;',
        options[:score_threshold], options[:since].to_i, options[:max_statuses]).each do |row|
        status = row2status(row)
        yield status
      end
    else
      @db.execute('select * from timeline where score > ? order by time asc limit ?;',
        options[:score_threshold], options[:max_statuses]).each do |row|
        status = row2status(row)
        yield status
      end
    end
  end

end

# composite pattern
class Evaluator
  
  def initialize
    super
  end

  def evaluate(status)
    0 # by default
  end

  def feedback(status)
    nil # by default
  end

  # TODO: marshal / unmarshalize

end

# scores if specific keyword has appeared on message
class KeywordEvaluator < Evaluator
  attr_accessor :keywords

  DEFAULT_SCORE = 100
  
  def initialize(keywords = {})
    if keywords.is_a? Array
      keywords = keywords.inject({}) do |r, i|
        r[i] = DEFAULT_SCORE; r
      end
    end

    @keywords = keywords
  end

  def evaluate(status)
    totalscore = 0

    @keywords.each_pair do |keyword, score|
      if status.message.match(keyword)
        totalscore += score
      end
    end

    totalscore
  end

end

# scores if any reply to me is included
class ReplyEvaluator < Evaluator

  DEFAULT_SCORE = 500

  def initialize(mynick)
    @mynick = mynick
  end

  def evaluate(status)
    status.message.match(@mynick) ? DEFAULT_SCORE : 0
  end

end

# scores if status has been post by specific user
class UserEvaluator < Evaluator
  attr_accessor :usernames

  DEFAULT_SCORE = 300

  def initialize(usernames)
    if usernames.is_a? Array
      usernames = usernames.inject({}) do |r, i|
        r[i] = DEFAULT_SCORE; r
      end
    end

    @usernames = usernames
  end

  def evaluate(status)
    totalscore = 0

    @usernames.each_pair do |hotnick, score|
      if status.nick == hotnick
        totalscore += score
      end
    end

    totalscore
  end

end

class BayesianEvaluator < Evaluator
  FACTOR = 300
  
  HINSI_WHITELIST = [
    /^動詞/,
    '形容詞',
    '名詞',
    ]

  HINSI_BLACKLIST = [
    '代名詞'
    ]

  def initialize(db)
    @db = db
    init_db

    @tagger = MeCab::Tagger.new()
  end

  def evaluate(status)
    status.traits = analyze_traits(status.message) unless status.traits
    
    ham = 1; spam = 1
    status.traits.each_pair do |k, v|
      s = 1; x = 0.8
      p = 0; n = 0
      @db.execute('select score, ntimes from bayes_wordlist where word = ?;') do |row|
        p = (row[0].to_f - 50) / 500
        n = row[1].to_i
      end

      f = (s*x + n*p).to_f / (s + n)
      
      ham *= f
      spam *= 1.0 - f
    end

    numtraits = status.traits.size
    ham = BayesianEvaluator.chi2inv(ham, 2 * numtraits)
    spam = BayesianEvaluator.chi2inv(spam, 2 * numtraits)

    (ham - spam) / 2 * FACTOR
  end

  def feedback(status)
    status.traits = analyze_traits(status.message) unless status.traits

    status.traits.each_pair do |k, v|
      score = 0
      ntimes = 1

      begin
        @db.execute('select score, ntimes from bayes_wordlist where word = ?;') do |row|
          score += row[0].to_i
          ntimes += row[1].to_i
        end

        if ntimes == 1
          @db.execute('insert into bayes_wordlist values(?, ?);', k, v * status.score, 1)
        else
          @db.execute('update bayes_wordlist set score = ?, ntimes = ? where word = ?;', score, ntimes, word)
        end
      rescue SQLite3::SQLException => e
        puts "error while inserting a word into wordlist: #{e.inspect}"
      end
    end
  end

private

  def init_db
    begin
      @db.execute('drop table bayes_wordlist') if CLEAR_DB
    rescue SQLite3::SQLException => e
    end

    begin
      @db.execute <<END
      create table bayes_wordlist (
        word TEXT,
        score INTEGER,
        ntimes INTEGER
      );
END

      puts "new table 'bayes_wordlist' has been created"
    rescue SQLite3::SQLException => e
      # table already existed
    end
  end
  
  # move this to Status class
  def analyze_traits(msg)
    traits = {}
    begin
      node = @tagger.parseToNode(msg)

      while node do
        hinsi = node.feature

        ok = false
        HINSI_WHITELIST.each do |e|
          if hinsi.match(e)
            ok = true
          end
        end
        HINSI_BLACKLIST.each do |e|
          if hinsi.match(e)
            ok = false
          end
        end

        if ok
          unless traits[node.surface]
            traits[node.surface] = 1
          else
            traits[node.surface] += 1
          end
        end

        node = node.next
      end
    rescue => e
      p e
      puts "error"
    end

    traits
  end

  # カイ２乗分布関数。あんまり自信ないけど多分bishopの実装は酷く間違っていると思う！！！
  def self.chi2inv(x, k)
    Math::exp(- x/2) / 2 * (1..(k/2-1)).inject(1.0) { |r, i| r * x * i }
  end

end

# multiple evaluators combined
# TODO: better name???
class EvaluatorComposer < Evaluator
  attr_reader :evalers
  
  def initialize
    @evalers = []
  end

  def evaluate(status)
    @evalers.inject(0) do |r, i|
      r += i.evaluate(status)
    end
  end

  def add_evaluator(evaler)
    # evaler has to have evaluate(status) implemented but there is no other limitations
    
    @evalers << evaler
  end

end

class App
  attr_reader :opts, :timeline
  
  def initialize(opts)
    @opts = opts

    # open sqlite db
    @db = SQLite3::Database.new(@opts[:dbfile])

    # setup Timeline
    @timeline = Timeline.new(@db)

    # setup Twitter client
    @twit = Twitter::Base.new(@opts[:twit_nick], @opts[:twit_pass])

    @nick_friends = @twit.friends.inject([]) {|r, i| r << i.screen_name; r}

    # setup evaluators
    @evaluator = EvaluatorComposer.new
    
    # -- KeywordEvaluator
    if @opts[:keywords]
      keywords = @opts[:keywords]
      keywordeval = KeywordEvaluator.new(keywords)

      @evaluator.add_evaluator(keywordeval)
    end

    # -- ReplyEvaluator
    @evaluator.add_evaluator(
      ReplyEvaluator.new(@opts[:twit_nick])
      )

    # -- UserEvaluator
    if @opts[:hotnicks]
      hotnicks = @opts[:hotnicks]
      usereval = UserEvaluator.new(hotnicks)

      @evaluator.add_evaluator(usereval)
    end

    # -- BayesianEvaluator
    @evaluator.add_evaluator(BayesianEvaluator.new(@db))
  end

  FRIENDS_SCORE = 100 # FIXME: move this to friends evaluator

  def update_twit 
    time_start = Time.now

    statuses = []
    @twit.timeline(:friends).each do |s|
      status = conv_status(s)

      status.score = FRIENDS_SCORE
      status.timeline = Status::TL_FRIENDS
      statuses << status
    end

    @twit.timeline(:public).each do |s|
      status = conv_status(s)

      next if @nick_friends.include?(status.nick)
      next unless status.is_Japanese?

      statuses << status
    end

    time_timelineget = Time.now

    statuses.uniq.each do |status|
      status.score += @evaluator.evaluate(status)
      if @timeline.add_status(status)
        @evaluator.feedback(status)
      end
    end

    time_evalend = Time.now
    
    if true
      puts "performance stat:"
      puts "  get timeline took:  #{time_timelineget - time_start} sec"
      puts "  statuses eval took: #{time_evalend - time_timelineget} sec"
    end
  end

  def main
    update_twit

    @timeline.console_out
  end

private
  def conv_status(s)
    text = CGI.unescapeHTML(REXML::Text::unnormalize(s.text))
    text.gsub!(/http:\/\/tinyurl\.com\/[a-z0-9]{6}/) do |turl|
      Tinyurl.new(turl).original
    end

    Status.new({
      :id => s.id,
      :time => Time.parse(s.created_at),
      :message => text,
      :source => s.source,

      :username => REXML::Text::unnormalize(s.user.name),
      :userimg => s.user.profile_image_url,
      :userloc => s.user.location,
      :userurl => s.user.url,
      :userid => s.user.id,
      :userprotected => s.user.protected,
      :nick => s.user.screen_name,

      :in_reply_to_status_id => s.in_reply_to_status_id,
      :in_reply_to_user_id => s.in_reply_to_user_id,
      })
  end
end

end # of module AdvTwit

unless $advtwit_opts
  require ARGV[0] || 'advtwit.cfg.rb'
end

if __FILE__ == $0
  app = AdvTwit::App.new($advtwit_opts)
  app.main
end
