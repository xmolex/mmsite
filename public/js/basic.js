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