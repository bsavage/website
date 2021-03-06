(function() {
  var version = '4.1.3';
  var url = 'https://openaccessbutton.org/static/bookmarklet';
  url = 'https://dev.openaccessbutton.org/static/bookmarklet'; // COMMENT THIS OUT BEFORE GOING TO LIVE
  var fls = ['bookmarklet.css','oab.js'];
  for (var i = 0; i < fls.length; i++) {
    var tp = fls[i].indexOf('css') !== -1 ? 'link' : 'script';
    var ms = document.createElement(tp);
    if ( tp === 'link' ) {
      ms.rel = 'stylesheet';
      ms.href = url + '/' + fls[i] + '?v=' + version;
    } else {
      ms.src = url + '/' + fls[i] + '?v=' + version;      
    }
    document.getElementsByTagName('head')[0].appendChild(ms);
  }
  setTimeout(function() {
    var popup = document.createElement('div');
    popup.setAttribute('id','oabutton_popup');
    popup.setAttribute('class','reset-this');
    popup.innerHTML = '<img id="iconloading" style="width:40px;height:40px;" src="' + url + '/img/spin_orange.svg" /><div id="isopen" style="display:none;"><p>This article is available!</p><p><a id="linkopen" href=""><img style="width:100%;" src="' + url + '/img/open.png" /></a></p></div><div id="isclosed" style="display:none;"><p>This article is not currently available,<br>but you can request it from the author.</p><p><a id="linkclosed" href=""><img style="width:100%;" src="' + url + '/img/closed.png" /></a></p></div><div id="iserror" style="display:none;"><p>Sorry, there was an error. Please click to report it.</p><p><a id="linkerror" href=""><img style="width:100%;" src="' + url + '/img/error.png" /></a></p></div><a href="#" target="_blank" id="iconarticle" style="display:none;padding-left:5px;padding-right:3px;"></a>';
    document.body.appendChild(popup);
    oabutton_ui(undefined,version);
  },1500);
})
})();
