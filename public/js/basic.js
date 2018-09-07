function RemoveElem(elem) {
   if (elem) {elem.parentNode.removeChild(elem);}
}

function get_cookie(cookie_name) {
  var results = document.cookie.match ( '(^|;) ?' + cookie_name + '=([^;]*)(;|$)' );
  if ( results ) {return ( unescape ( results[2] ) );}
  else {return null;}
}

// получаем размер в байтах, а отдаем текстовую строку с удобным отображением
function size_to_str(size) {
    // проверка на число
    var n = parseInt(size); 
    if (isNaN(n)) {return size;}

    size = parseInt(size);
   
    if (! Math.floor(size / 1024 / 1024 / 1024) < 1 ) {
        // гигабайты
        size = size / 1024 / 1024 / 1024;
        if ( size - Math.floor(size) == 0 ) {return(size + ' Gb');}
        else {size = size.toFixed(2); return(size + ' Gb');}
    }
    else if (! Math.floor(size / 1024 / 1024) < 1 ) {
        // мегабайты
        size = size / 1024 / 1024;
        if ( size - Math.floor(size) == 0 ) {return(size + ' Mb');}
        else {size = size.toFixed(2); return(size + ' Mb');}
    }
    else if (! Math.floor(size / 1024) < 1 ) {
        // килобайты
        size = size / 1024;
        if ( size - Math.floor(size) == 0 ) {return(size + ' Kb');}
        else {size = size.toFixed(2); return(size + ' Kb');}
    }
    else {
        // байты
        return(size + ' bytes');
    }
}


function ajax_fail( jqXHR, exception ) {
    var msg = '';
    if (jqXHR.status === 0) {
            msg = 'Not connect, verify Network.';
    } else if (jqXHR.status == 404) {
            msg = 'Requested page not found. [404]';
    } else if (jqXHR.status == 500) {
            msg = 'Internal Server Error [500].';
    } else if (exception === 'parsererror') {
            msg = 'Requested JSON parse failed.';
    } else if (exception === 'timeout') {
            msg = 'Time out error.';
    } else if (exception === 'abort') {
            msg = 'Ajax request aborted.';
    } else {
            msg = 'Uncaught Error.' + jqXHR.responseText;
    }
    return msg;
}

// генерация случайного токена
function generate_token(length){
    var a = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890".split("");
    var b = [];  
    for (var i=0; i<length; i++) {
        var j = (Math.random() * (a.length-1)).toFixed(0);
        b[i] = a[j];
    }
    return b.join("");
}

function sleep( ms, callback ) {
   setTimeout(function(){callback();}, ms);
}

function file_incriment( file_id, target ) {
    $.ajax({
        type: 'POST',
        data: ({ "file_id" : file_id, target : target }),
        async: true,
        url: '/count',
        success: function (data, textStatus) {}
   });
}

function file_view( file_id ) {
    $.ajax({
        type: 'POST',
        data: ({ "file_id" : file_id }),
        async: true,
        url: '/view',
        success: function (data, textStatus) {
            if (data == 1) {
                if( typeof videoViews !== "undefined" ) {
                    videoViews.push(file_id);
                    mark_file_views();
                }
            }
        }
   });
}

function all_view_from_group( group_id, type, loading_id ) {
    // loading open
    $("#" + loading_id).css('display','inline-block');

    if (! type) {group_id = group_id * -1;}
    $.ajax({
        type: 'POST',
        data: ({ "group_id" : group_id }),
        async: true,
        url: '/viewall',
        success: function (data, textStatus) {
            $("#" + loading_id).css('display','none');
            var data = JSON.parse(data);
            if (data.error) { alert('Ошибка: ' + data.error); return false; }
            if( typeof videoViews !== "undefined" ) {
                videoViews = data;
                if (! type) {unmark_file_views();}
                else {mark_file_views();}
                
            }
        },
        error: function (jqXHR, exception) {
            // loading close
            $("#" + loading_id).css('display','none');
            // print error
            var mess = ajax_fail(jqXHR, exception);
            alert(mess);
        } 
   });
   return false;
}

function unmark_file_views() {
    // меняем отображение файлов, которые пользователь еще не просмотрел
    if( typeof videoViews !== "undefined" ) {
        for (i = 0; i < videoViews.length; i++) {
            $("#file-title-" + videoViews[i]).css('color', '#337ab7');
        }
    }
}

function mark_file_views() {
    // меняем отображение файлов, которые пользователь уже просмотрел
    if( typeof videoViews !== "undefined" ) {
        for (i = 0; i < videoViews.length; i++) {
            $("#file-title-" + videoViews[i]).css('color', '#999');
        }
    }
}

function subscribe( group_id ) {
    $.ajax({
        type: 'POST',
        data: ({ "group_id" : group_id }),
        async: true,
        url: '/subscribe',
        success: function (data, textStatus) {
            if (data == '') {alert('не удалось'); return;}
            $("#bell").removeClass("bell-noactive bell-active")
            if (data == '0') {$("#bell").addClass("bell-noactive");}
            else {$("#bell").addClass("bell-active");}
        }
   });
}

function getHashParams() {

    var hashParams = {};
    var e,
        a = /\+/g,  // Regex for replacing addition symbol with a space
        r = /([^&;=]+)=?([^&;]*)/g,
        d = function (s) { return decodeURIComponent(s.replace(a, " ")); },
        q = window.location.hash.substring(1);

    while (e = r.exec(q))
       hashParams[d(e[1])] = d(e[2]);

    return hashParams;
}

function goto_subscribe() {
    if (typeof filter_modify == 'function') {
        filter_modify( 'type', 2 );
        return false;
    }
    return true;
}