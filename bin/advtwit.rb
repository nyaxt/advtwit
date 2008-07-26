#!/usr/bin/env ruby
# advtwit: twitter client for freaks 上級者向けtwitterクライアント（笑)
#
#License::
# Copyright (c) 2007, Kouhei Ueno # fixme: add here
# 
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
# 
#     * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
#     * Neither the name of the nyaxtstep.com nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

$KCODE = 'u'

require 'rubygems'
require 'pit'
require 'twitter'
require 'nkf'
require 'tinyurl'
require 'rexml/document'
require 'MeCab'

module AdvTwit

class Status
  attr_accessor :user, :nick, :message, :score

  def initialize(hash)
    # atode kaku
=begin
    hash.each_pair do |k, v|
      
    end
=end
    
    @user = hash[:user]
    @nick = hash[:nick]
    @message = hash[:message]
  end

  def to_s 
    "#{@user} (#{nick}): #{message} (#{score})"
  end

  def inspect; to_s; end

  def is_Japanese?
    not @message.match(/[あ-んア-ン]/).nil?
  end

end

class Timeline
  attr_accessor :statuses

  def initialize
    @statuses = []
  end

  def add_status(status)
    status = Status.new(status) unless status.is_a? Status

    @statuses << status
  end

  def console_out
    @statuses.each do |status|
      puts status.to_s
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
  attr_accessor :users

  DEFAULT_SCORE = 300

  def initialize(users)
    if users.is_a? Array
      users = users.inject({}) do |r, i|
        r[i] = DEFAULT_SCORE; r
      end
    end

    @users = users
  end

  def evaluate(status)
    totalscore = 0

    @users.each_pair do |hotnick, score|
      if status.nick == hotnick
        totalscore += score
      end
    end

    totalscore
  end

end

class BayesianEvaluator < Evaluator
  
  HINSI_WHITELIST = [
    /^動詞/,
    '形容詞',
    '名詞',
    ]

  HINSI_BLACKLIST = [
    '代名詞'
    ]

  def initialize
    @tagger = MeCab::Tagger.new()
  end

  def evaluate(status)
    # TODO: implement !
    0
  end

  def feedback(status)
    # TODO: implement !

    p trait(status.message)
  end

private
  
  def trait(msg)
    trait = {}
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
          unless trait[node.surface]
            trait[node.surface] = 1
          else
            trait[node.surface] += 1
          end
        end

        node = node.next
      end
    rescue => e
      p e
      puts "error"
    end

    trait
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

    @timeline = Timeline.new

    # setup Twitter client
    @twit = Twitter::Base.new(@opts[:twit_user], @opts[:twit_pass])

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
      ReplyEvaluator.new(@opts[:twit_user])
      )

    # -- UserEvaluator
    if @opts[:hotnicks]
      hotnicks = @opts[:hotnicks]
      usereval = UserEvaluator.new(hotnicks)

      @evaluator.add_evaluator(usereval)
    end

    # -- BayesianEvaluator
    @evaluator.add_evaluator(BayesianEvaluator.new)
  end

  FRIENDS_SCORE = 100

  def update_twit 
    time_start = Time.now

    statuses = []
    @twit.timeline(:friends).each do |s|
      msg = CGI.unescapeHTML(REXML::Text::unnormalize(s.text))
      msg.gsub!(/http:\/\/tinyurl\.com\/[a-z0-9]{6}/) do |turl|
        Tinyurl.new(turl).original
      end

      status = Status.new({
        :message => msg,
        :user => REXML::Text::unnormalize(s.user.name),
        :nick => s.user.screen_name,
        :score => FRIENDS_SCORE
        })
      statuses << status
    end

    @twit.timeline(:public).each do |s|
      msg = CGI.unescapeHTML(REXML::Text::unnormalize(s.text))

      status = Status.new({
        :message => msg,
        :user => REXML::Text::unnormalize(s.user.name),
        :nick => s.user.screen_name
        })

      next if @nick_friends.include?(status.nick)
      next unless status.is_Japanese?

      statuses << status
    end

    time_timelineget = Time.now

    statuses.each do |status|
      status.score = @evaluator.evaluate(status)
      @timeline.add_status(status)
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
end

end

opts = {}
unless false #opts[:twit_user] and opts[:twit_pass]
  credentials = Pit.get("advtwit", :require => {
    "twit_user" => "twitter username",
    "twit_pass" => "twitter password",
    })

  opts[:twit_user] ||= credentials["twit_user"]
  opts[:twit_pass] ||= credentials["twit_pass"]
end
opts[:keywords] = ['advtwit', 'nyaxt']
opts[:hotnicks] = ['nyaxt', 'syou6162', 'showyou']

app = AdvTwit::App.new(opts)
app.main
