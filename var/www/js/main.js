$(function() {
  // === timeline view

  function unescapeHTML(str)
  {
    return str.replace(/&amp;/g,'&').replace(/&lt;/g,'<').replace(/&gt;/g,'>');
  }

  var statusTemplate = unescapeHTML($("#template").html());

  var latestStatus = new Date(); latestStatus.setTime(latestStatus.getTime() - 86400 * 1000); // tweets from yesterday
  var columnAB = 'a';

  var regAtReply = /@\w+/gi;
  // adopted from http://furyu.tea-nifty.com/script/cvtUrlToLink.user.js
  var regURL = /(h?)(ttps?:\/\/[-_.!~*()a-zA-Z0-9;/?:@&=+$,%#]+)/mgi;

  function appendStatus()
  {
    var scrname = this['user']['screen_name'];
  
    var scoreclass = '';
    if(this['score'] > 500)
    {
      scoreclass = 'veryhighscore highscore';
    }
    else if(this['score'] > 400)
    {
      scoreclass = 'highscore'; 
    }
    else if(this['score'] < 130)
    {
      scoreclass = 'lowscore';
    }

    var text = this['text'];
    text = text
      .replace(regURL, function(url) { return '<a href="'+url+'" target="_blank">'+url+'</a>'; })
      .replace(regAtReply, function(nick) { return '<a href="http://twitter.com/'+nick.substr(1,100)+'" target="_blank">'+nick+'</a>'; });

    status = statusTemplate
      .replace(/%ab%/, columnAB + ' ' + scoreclass)
      .replace(/%img%/, this['user']['profile_image_url'])
      .replace(/%nick%/, "<a href='http://twitter.com/"+scrname+"'>"+scrname+"</a>")
      .replace(/%username%/, this['user']['name'])
      .replace(/%score%/, this['score'])
      .replace(/%created_at%/, this['created_at'])
      .replace(/%message%/, text);

    $("#statuses_container").prepend(status);
    if(columnAB == 'a')
    {
      columnAB = 'b'; 
    }
    else
    {
      columnAB = 'a'; 
    }

    var created_at = new Date(this['created_at']);
    if(latestStatus < created_at)
    {
      latestStatus = created_at; 
    }

    var domst = $("#statuses_container").children().slice(0,1);
    domst.hover(
      function() {
        $(this).addClass('onhover');
      },
      function() {
        $(this).removeClass('onhover');
      }
    );

    var domstimg = domst.find('img.userimg');
    domstimg.click(function() {
        var nick = $(this).parent().find('.nick').text();
        var domtext = $("#status");
        domtext.attr('value', nick + ' ' + domtext.attr('value'));
      }
    );
  }

  function deleteOldStatus()
  {
    $("#statuses_container").children().slice(200).remove();
  }

  var refreshTimelineTimerId = -1;
  function refreshTimelineJSON(json)
  {
    if(refreshTimelineTimerId != -1)
    {
      clearTimeout(refreshTimelineTimerId); 
    }

    $.each(json, appendStatus);
    deleteOldStatus();
    refreshTimelineTimerId = setTimeout(refreshTimeline, 10000);
  }

  var firstUpdate = true;
  function refreshTimeline()
  {
    $.getJSON("/atw/statuses/advtwit_timeline.json",
      {
        'first_update':firstUpdate,
        'since':latestStatus.toGMTString()
      },
      refreshTimelineJSON
      );

    if(firstUpdate) { firstUpdate = false; }
  }

  $('input#refresh').click(refreshTimeline);

  refreshTimeline();

  // === status textarea
  function updateCharLeft()
  {
    var length = $(this).attr('value').length;
    $('#statusleft').text((180 - length) + " characters left.");
  }

  $('#postform textarea#status').change(updateCharLeft);
  $('#postform textarea#status').keydown(updateCharLeft);
})
