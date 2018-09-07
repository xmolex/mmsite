function GetVideo(id) {
  if (!id) {id = 0;}
  var elem = '';
  if (!PopupGetVideoElVar || !document.getElementById(PopupGetVideoElVar.id)) {
    // меняем размер для маленьких экранов
    var doc_w = $(document).width();
    if (videoWidth > doc_w) {
        // необходимо корректировать размер
        var coof = videoWidth / doc_w;
        videoWidth = doc_w;
        videoHeight = Math.floor(videoHeight / coof);
        PLAYER_PLAYLIST_WIDTH = Math.floor(PLAYER_PLAYLIST_WIDTH / coof);
    }
  
    // поле close
    var parent = document.getElementsByTagName('BODY')[0];
    var parentfirst = parent.getElementsByTagName('DIV')[0]
    elem = document.createElement('div');
    POPUPZINDEX++;
    elem.id = 'p-w-e-c';
    elem.style.zIndex = POPUPZINDEX;
    elem.style.position = 'absolute';
    var x = $(document).width();  if (videoWidth  > x) {x = videoWidth;}
    var y = $(document).height(); if (videoHeight > y) {y = videoHeight;}
    elem.style.width = x + 'px';
    elem.style.height = y + 'px';
    elem.style.backgroundColor = '#000';
    parent.insertBefore(elem,parentfirst);
    $("body #p-w-e-c").fadeTo(0, 0.6);
  
    // поле с видео
    parent = document.getElementsByTagName('BODY')[0];
    parentfirst = parent.getElementsByTagName('DIV')[0]
    elem = document.createElement('div');
    elem.id = 'p-w-e';
    elem.style.zIndex = POPUPZINDEX + 1;
    elem.style.position = 'absolute';
    elem.style.top = '0px';
    elem.style.left = '0px';
    parent.insertBefore(elem,parentfirst);
    PopupGetVideoElVar = elem;
    elem.innerHTML = '<div id="video-body" style="width: ' + videoWidth + 'px; height: ' + videoHeight + 'px;"></div>';
    PopupBoxGetOrd('p-w-e');
    
  } else {elem = PopupGetVideoElVar;}
  
  jwplayer("video-body").setup({
    file: "",
    image: "",
    playlist: videolist,
    listbar: {
        position: "right",
        size: PLAYER_PLAYLIST_WIDTH
      },
    width: videoWidth,
    height: videoHeight,
    aspectratio: videoAspect
    //stretching: "exactfit"
  });
  
  if (id > 0) {
    jwplayer().playlistItem(id);
    jwplayer().play(false);
  }
  
  jwplayer().onBuffer(function() {
    var lst = jwplayer().getPlaylistItem();
    file_incriment( lst.id, 1 );
    if ( typeof videoUserId !== "undefined" ) {
        if (videoUserId > 0) {file_view( lst.id );}
    }
  });
  
  document.getElementById('p-w-e-c').onclick = function(e) {
    document.getElementById('p-w-e-c').parentNode.removeChild(document.getElementById('p-w-e-c'));
    document.getElementById('p-w-e').parentNode.removeChild(document.getElementById('p-w-e'));
    hasPlayed = false;
  }
}

// функция установления координат для вывода всплывающего окошка
function PopupBoxGetOrd(ident) {
  if (document.getElementById(ident)) {
    var ClientX=(window.innerWidth)?window.innerWidth:((document.all)?document.body.offsetWidth:null);
    var ClientY=(window.innerHeight)?window.innerHeight:((document.all)?document.body.offsetHeight:null);
    var x = Math.floor((ClientX / 2) + getBodyScrollLeft());
    var y = Math.floor((ClientY / 2) + getBodyScrollTop());
    var obj = document.getElementById(ident);
    x = x - Math.floor(obj.offsetWidth / 2); if (x < 0) {x = 0;}
    y = y - Math.floor(obj.offsetHeight / 2); if (y < 0) {y = 0;}
    obj.style.top = y + 'px';
    obj.style.left = x + 'px';
    return true;
  }
}

    function getBodyScrollTop()
     {
       return self.pageYOffset || (document.documentElement && document.documentElement.scrollTop) || (document.body && document.body.scrollTop);
     }

    function getBodyScrollLeft()
     {
       return self.pageXOffset || (document.documentElement && document.documentElement.scrollLeft) || (document.body && document.body.scrollLeft);
     }
