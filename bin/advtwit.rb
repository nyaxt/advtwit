#!/usr/bin/ruby
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
require 'rexml/document'

module AdvTwit

class Status
  attr_accessor :user, :message, :score

  def initialize(hash)
    # atode kaku
=begin
    hash.each_pair do |k, v|
      
    end
=end
    
    @user = hash[:user]
    @message = hash[:message]
  end

  def to_s 
    "#{@user}: #{message} (#{score})"
  end

  def inspect; to_s; end

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
    super    
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

    @twit = Twitter::Base.new(@opts[:twit_user], @opts[:twit_pass])
    @timeline = Timeline.new

    @evaluator = EvaluatorComposer.new
    
    if @opts[:keywords]
      keywords = @opts[:keywords]
      keywordeval = KeywordEvaluator.new(keywords)

      @evaluator.add_evaluator(keywordeval)
    end

    @evaluator.add_evaluator(
      ReplyEvaluator.new(@opts[:twit_user])
      )
  end

  def update_twit 
    @twit.timeline(:friends).each do |s|
      status = Status.new({
        :message => REXML::Text::unnormalize(s.text),
        :user => s.user.name
        })

      status.score = @evaluator.evaluate(status)
      @timeline.add_status(status)
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

app = AdvTwit::App.new(opts)
app.main
