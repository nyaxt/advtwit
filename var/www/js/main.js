$(function() {
  function unescapeHTML(str)
  {
    return str.replace(/&amp;/g,'&').replace(/&lt;/g,'<').replace(/&gt;/g,'>');
  }

  var statusTemplate = unescapeHTML($("#template").html());

  var latestStatus = new Date(); latestStatus.setTime(latestStatus.getTime() - 86400 * 1000); // tweets from yesterday
  var columnAB = 'a';

  function appendStatus()
  {
    var scrname = this['user']['screen_name'];
    status = statusTemplate
      .replace(/%ab%/, columnAB)
      .replace(/%img%/, this['user']['profile_image_url'])
      .replace(/%nick%/, "<a href='http://twitter.com/"+scrname+"'>"+scrname+"</a>")
      .replace(/%username%/, this['user']['name'])
      .replace(/%score%/, this['score'])
      .replace(/%created_at%/, this['created_at'])
      .replace(/%message%/, this['text']);

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
  }

  function deleteOldStatus()
  {
    $("#statuses_container").children().slice(200).remove();
  }

  function updateTimelineJSON(json)
  {
    $.each(json, appendStatus);
    deleteOldStatus();
    setTimeout(updateTimeline, 10000);
  }

  function updateTimeline()
  {
    $.getJSON("/atw/statuses/advtwit_timeline.json",
      {
        'since':latestStatus.toGMTString()
      },
      updateTimelineJSON
      );
  }

  updateTimeline();
})
