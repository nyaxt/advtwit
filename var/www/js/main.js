$(function() {
  function unescapeHTML(str)
  {
    return str.replace(/&amp;/g,'&').replace(/&lt;/g,'<').replace(/&gt;/g,'>');
  }

  var statusTemplate = unescapeHTML($("#template").html());

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

    $("#statuses_container").append(status);
    if(columnAB == 'a')
    {
      columnAB = 'b'; 
    }
    else
    {
      columnAB = 'a'; 
    }
  }

  function updateTimeline(json)
  {
    $.each(json, appendStatus);
  }

  $.getJSON("/atw/statuses/advtwit_timeline.json", updateTimeline);
})
