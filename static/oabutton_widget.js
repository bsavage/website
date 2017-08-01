
// to use this widget, just include this js file, and then call oabutton_widget() in a script on the page
// If jquery is not already used on the site, jquery is required too.
// bootstrap can optionally be used to apply styling
// this can be done like so:
// <script src="https://static.cottagelabs.com/jquery-1.10.2.min.js"></script>
// <link rel="stylesheet" href="https://static.cottagelabs.com/bootstrap-3.0.3/css/bootstrap.min.css">
// <script src="https://openaccessbutton.org/static/oabutton_widget.js"></script>
// <script>jQuery(document).ready(function() { oabutton_widget(); });</script>

// need an input field called oabutton_url
// and an oabutton_find button to trigger it (although triggers on enter too)
// and oabutton_availability div required for inserting results
// and optional oabutton_loading

var oabutton_widget = function(opts) {
  if (opts === undefined) opts = {};
  var api = opts.api ? opts.api : 'https://api.openaccessbutton.org';
  var site = opts.site ? opts.site : 'https://openaccessbutton.org';
  if (opts.element === undefined && $('#oabutton_widget').length === 0) opts.element = 'body';
  
  if (opts.element) $(opts.element).append('<div id="oabutton_widget"></div>');
  var w = '<div class="input-group">\
    <textarea id="oabutton_url" class="form-control" style="min-height:40px;height:40px;font-size:1.1em;" placeholder="Search Open Access Button with URL, DOI, PMID, PMC ID, Title, or Citation"></textarea>\
    <div class="input-group-btn">\
      <a class="btn btn-primary btn-block" href="#" id="oabutton_find" style="min-height:40px;height:40px;font-size:1.1em;padding:7px 10px 5px 10px;"><i class="glyphicon glyphicon-search"></i></a>\
    </div>\
  </div>\
  <div id="oabutton_loading" style="display:none;"><img style="width:30px;" src="' + site + '/static/spin_orange.svg"></div>\
  <div id="oabutton_availability"></div>';
  $('#oabutton_widget').html(w);

  var availability = function(e) {
    if ($(this).attr('id') === 'oabutton_find' || e === undefined || e.keyCode === 13) {
      if (e && $(this).attr('id') === 'oabutton_find') e.preventDefault();
      var url = $('#oabutton_url').val().trim();
      if (!url.length) {
        $('#oabutton_url').css('border-color','#f04717').focus();
        return;
      }
      if (url.lastIndexOf('.') === url.length-1) url = url.substring(0,url.length-1);
      $('#oabutton_loading').show();
      var opts = {
        type:'POST',
        url:api+'/availability',
        cache: false,
        processData: false,
        contentType: 'application/json',
        dataType: 'json',
        data: JSON.stringify({url:url,plugin:'widget',embedded:window.location.href}),
        success: function(data) {
          $('#oabutton_loading').hide();
          $('#oabutton_availability').show();
          var has = {};
          if (data.data.availability.length > 0) {
            for ( var a in data.data.availability ) {
              has[data.data.availability[a].type] = {url:data.data.availability[a].url};
            }
          }
          if (data.data.requests.length > 0) {
            for ( var r in data.data.requests ) {
              if (!has[data.data.requests[r].type]) has[data.data.requests[r].type] = {id:data.data.requests[r]._id,ucreated:data.data.requests[r].ucreated,usupport:data.data.requests[r].usupport};
            }
          }
          if (data.data.match && data.data.match.indexOf('http') !== 0 && data.data.meta && data.data.meta.article && data.data.meta.article.doi) data.data.match = 'https://doi.org/' + data.data.meta.article.doi;
          if (JSON.stringify(has) === '{}') {
            if (data.data.match.indexOf('http') === 0) {
              var dr = {};
              try { dr.title = data.data.meta.article.title; } catch(err) {}
              try { dr.doi = data.data.meta.article.doi; } catch(err) {}
              try { dr.url = data.data.match; } catch(err) {}
              var opts = {
                type:'POST',
                url: api+'/request?fast=true',
                cache:false,
                processData:false,
                contentType: 'application/json',
                dataType: 'json',
                data: JSON.stringify(dr),
                success: function(resp) {
                  window.location = site + '/request/' + resp._id;
                },
                error: function() {
                  window.location = site + '/request?url=' + encodeURIComponent(data.data.match);
                }
              }
              $.ajax(opts);
            } else {
              $('#oabutton_availability').html('<p>Sorry, we couldn\'t find anything for <b>' + data.data.match + '</b>.</p><p>Matching titles and citations can be tricky. Please find a URL, DOI, PMID or PMCID and <a href="/">try again</a>.</p>');
            }
          } else if (has.article && !has.data) {
            var availability = '';
            if (has.article.id) {
              availability += '<p style="color:#212f3f;padding-top:50px;">';
              if (has.article.ucreated) {
                availability += 'You already created a request for this article <a class="btn btn-action" href="/request/' + has.article.id + '">View the request</a></p>';
              } else if (has.article.usupport) {
                availability += 'You already support a request for this article <a class="btn btn-action" href="/request/' + has.article.id + '">View the request</a></p>';
              } else {
                availability += 'Someone has requested access to the article <a class="btn btn-action" href="/request/' + has.article.id + '?support=true">Notify me</a></p>';
              }
            } else {
              availability += '<h2>This article is available!</h2>';
              availability += '<p"><a style="word-wrap:break-word;overflow-wrap:break-word;" target="_blank" href="' + has.article.url + '">' + has.article.url + '</a></p>';
              availability += '<p>Not what you were expecting? <a target="_blank" href ="' + site + '/feedback#wrong?searched=' + encodeURIComponent(url) + '&given=' + encodeURIComponent(has.article.url) + '">Report an error</a>.</p>';
              availability += '<p> You can <a target="_blank" href="' + site + '/request?url=' + encodeURIComponent(data.data.match) + '">request it from the author</a> if it isn\'t available.</p>';
            }
            availability += '<p>';
            availability += 'Want the data supporting the article? ';
            availability += '<a target="_blank" class="btn btn-action" href="' + site + '/request?type=data&url=' + encodeURIComponent(data.data.match) + '">Request it from the author</a></p>';
            $('#oabutton_availability').html(availability);
          } else if (!has.article && has.data) {
            var availability = '<h2>This article is not available</h2>';
            availability += '<h3 style="text-align:center;"><a target="_blank" class="btn btn-action" href="' + site + '/request?url=' + encodeURIComponent(data.data.match) + '">Start a request</a></h3>';
            availability += '<p>';
            if (has.data.id) {
                availability += 'Someone has requested access to the data. <a target="_blank" class="btn btn-action" href="' + site + '/request/' + has.data.id + '?support=true">Notify me';
            } else {
              availability += 'However there is data available:</p>';
              availability += '<p style="text-align:center;"><a style="word-wrap:break-word;overflow-wrap:break-word;" target="_blank" href="' + has.data.url + '">' + has.data.url;
            }
            availability += '</a></p>';
            $('#oabutton_availability').html(availability);
          } else if (has.article && has.data) {
            if (has.article.id && has.data.id) {
              window.location = site + '/request/' + has.article.id;
            } else {
              var availability = '<h2>';
              if (has.article.url) {
                availability += 'This article is available!</h2>';
                availability += '<h><a style="word-wrap:break-word;overflow-wrap:break-word;" target="_blank" href="' + has.article.url + '">' + has.article.url;
              }
              if (has.article.id) {
                availability += 'Someone has requested access to the article. <a target="_blank" class="btn btn-action" href="' + site + '/request/' + has.article.id + '?support=true">Notify me';
              }
              availability += '</a></h3><p style="text-align:center;">';
              if (has.data.url) {
                availability += 'And there is data available for this article:</p><p style="text-align:center;">';
                availability += '<a style="word-wrap:break-word;overflow-wrap:break-word;" target="_blank" href="' + has.data.url + '">' + has.data.url;
              }
              if (has.data.id) {
                availability += 'Someone has requested access to the data. <a target="_blank" class="btn btn-action" href="' + site + '/request/' + has.data.id + '?support=true">Notify me';
              }
              availability += '</a></p>';
              $('#oabutton_availability').html(availability);
            }
          }
        },
        error: function() {
          $('#oabutton_loading').hide();
          $('#oabutton_loading').after('<p>Sorry, something went wrong with Open Access Button. <a target="_blank" href="' + site + '/feedback#bug">Can you let them know?</a></p>');
        }
      };
      $.ajax(opts);
    }
  }
  $('#oabutton_url').bind('keyup',availability);
  $('#oabutton_find').bind('click',availability);
}
