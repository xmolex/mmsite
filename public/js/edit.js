var tmpl_posters        = document.getElementById('TmplDataPosters').innerHTML;
var tmpl_shots          = document.getElementById('TmplDataShots').innerHTML;
var tmpl_files          = document.getElementById('TmplDataFiles').innerHTML;
var tmpl_subtitles      = document.getElementById('TmplDataSubtitle').innerHTML;
var tmpl_modal_image    = document.getElementById('TmplModalImage').innerHTML;
var tmpl_modal_file     = document.getElementById('TmplModalFile').innerHTML;
var tmpl_elem_countries = document.getElementById('TmplElemCountries').innerHTML;
var tmpl_elem_genres    = document.getElementById('TmplElemGenres').innerHTML;

var adding          = []; // хранит имена файлов отображенных на странице
var select          = []; // хранит имена файлов выбранных в popup окне
var data_info       = {}; // структура данных для добавления
var data_user_files = {}; // структура файлов, находящихся в директории пользователя
var id_to_name      = {}; // структура хранения идентификаторов и названий файлов для быстрого поиска

// поиск областей в DOM для дальнейшего использования
var inb_form_val_kinopoisk_id   = document.getElementById('form-kinopoisk-id');
var inb_form_val_title          = document.getElementById('form-title');
var inb_form_val_title_orig     = document.getElementById('form-title-orig');
var inb_form_val_is_serial      = document.getElementById('form-is-serial');
var inb_form_val_year           = document.getElementById('form-year');
var inb_form_val_allow_age      = document.getElementById('form-allow-age');
var inb_form_val_description    = document.getElementById('form-description');
var inb_form_val_countries      = document.getElementById('form-countries');
var inb_form_val_genres         = document.getElementById('form-genres');
var inb_posters_data            = document.getElementById('posters-data');
var inb_shots_data              = document.getElementById('shots-data');
var inb_files_data              = document.getElementById('files-data');

// получаем список файлов в пользовательской директории
get_user_files();
// получаем структуру из json
get_data_info_from_json();
// из структуры заполняем общую информацию
reload_total_info();
// из структуры формируем отображение файлов
reload_files_from_data_info();

// функция установки общей информации из структуры
function reload_total_info() {
    if (data_info.kinopoisk_id){ inb_form_val_kinopoisk_id.value= data_info.kinopoisk_id;} else { inb_form_val_kinopoisk_id.value= 0; }
    if (data_info.title)       { inb_form_val_title.value       = data_info.title;       } else { inb_form_val_title.value       = ''; }
    if (data_info.title_orig)  { inb_form_val_title_orig.value  = data_info.title_orig;  } else { inb_form_val_title_orig.value  = ''; }
    if (data_info.year)        { inb_form_val_year.value        = data_info.year;        } else { inb_form_val_year.value        = 0; }
    if (data_info.allow_age)   { inb_form_val_allow_age.value   = data_info.allow_age;   } else { inb_form_val_allow_age.value   = 0; }
    if (data_info.is_serial)   { inb_form_val_is_serial.value   = data_info.is_serial;   } else { inb_form_val_is_serial.value   = 0; }
    if (data_info.description) { inb_form_val_description.value = data_info.description; } else { inb_form_val_description.value = ''; }
    
    // страны
    var etalon = JSON.parse(countries_json);
    for (i = 0; i < data_info.countries.length; i++) {
        var tmpl = tmpl_elem_countries;
        tmpl = tmpl.replace( /%ID%/g, data_info.countries[i] );
        tmpl = tmpl.replace( /%TITLE%/g, etalon[data_info.countries[i]]);
        $("#data-countries-body").append(tmpl);
        $(inb_form_val_countries).val('');
    }
    
    // жанры
    var etalon = JSON.parse(genres_json);
    for (i = 0; i < data_info.genres.length; i++) {
        var tmpl = tmpl_elem_genres;
        tmpl = tmpl.replace( /%ID%/g, data_info.genres[i] );
        tmpl = tmpl.replace( /%TITLE%/g, etalon[data_info.genres[i]]);
        $("#data-genres-body").append(tmpl);
        $(inb_form_val_genres).val('');
    }
}

// функция сохранения изменений общей информации в структуре
function save_total_info( type, val ) {
    var tmp = {};
    tmp.group_id = data_info.group_id;
    
    if (type == 'genres' || type == 'countries') {
        tmp[type] = data_info[type];
    }
    else {
        tmp[type] = val;
    }
    var str = JSON.stringify(tmp);
    $.ajax({
        type: 'POST',
        data: ({ "json" : str }),
        async: true,
        url: '/edit',
        success: function (data, textStatus) {
            var data = JSON.parse(data);
            if (data.error) { alert('Ошибка: ' + data.error); return false; }
        }               
   });
}


// функция добавления жанра/страны
function info_create( obj_type, obj_value ) {
    // выбираем структуру и шаблон в зависимости от типа
    var etalon;
    var tmpl;
    var form;
    if      (obj_type == 'countries') {etalon = JSON.parse(countries_json); tmpl = tmpl_elem_countries; form = inb_form_val_countries;}
    else if (obj_type == 'genres')    {etalon = JSON.parse(genres_json);    tmpl = tmpl_elem_genres;    form = inb_form_val_genres;}
    else {return;}
    
    obj_value = obj_value.toUpperCase();

    // проходимся по эталонной структуре и находим идентификатор
    var obj_id = 0;
    for( key in etalon ) {
        if ( etalon[key].toUpperCase() == obj_value ) {
            obj_id    = key;
            obj_value = etalon[key];

            // проходимся по уже добавленным элементам и проверяем, не добавлен ли он уже
            if (obj_type == 'countries') {
                for (i = 0; i < data_info.countries.length; i++) {if (data_info.countries[i] == obj_id) {return;}}
            }
            else if (obj_type == 'genres') {
                for (i = 0; i < data_info.genres.length; i++) {if (data_info.genres[i] == obj_id) {return;}}
            }

            break;
        }
    }
    
    if (! obj_id) {return;}

    // если дошли сюда, значит добавляем
    
    // правим шаблон и вставляем его в область
    tmpl = tmpl.replace( /%ID%/g, obj_id );
    tmpl = tmpl.replace( /%TITLE%/g, obj_value );
    
    if (obj_type == 'countries') {
        data_info.countries.push(obj_id);
        $("#data-countries-body").append(tmpl);
    }
    else if (obj_type == 'genres') {
        data_info.genres.push(obj_id);
        $("#data-genres-body").append(tmpl);
    }

    // чистим поле ввода
    $(form).val('');
    
    // сохраняем
    save_total_info( obj_type, 0 );
}

// функция удаления жанра/страны
function info_delete( obj_type, obj_id ) {
    if (obj_type == 'countries') {
        for (i = 0; i < data_info.countries.length; i++) {
            if (data_info.countries[i] == obj_id) {
                data_info.countries[i] = '';
                data_info.countries = $.grep(data_info.countries, function(el){return el != ''});
                break;
            }
        }
    }
    else if (obj_type == 'genres') {
        for (i = 0; i < data_info.genres.length; i++) {
            if (data_info.genres[i] == obj_id) {
                data_info.genres[i] = '';
                data_info.genres = $.grep(data_info.genres, function(el){return el != ''});
                break;
            }
        }
    }
    else {return;}
    
    // удаляем объект из DOM
    var obj = document.getElementById('elem-' + obj_type + '-' + obj_id);
    if (obj) {RemoveElem(obj);}
    
    // сохраняем
    save_total_info( obj_type, 0 );
}

// функции инициализации выбора файлов в popup окне
// помимо типа, может потребоваться и файл, если мы хотим добавить привязанные в родителю файлы
var popup_type;
var popup_id;
function modal_choose_files( type, id ) {

    // записываем нужную информацию в глобальные переменные, чтобы работать с ними из других функций
    popup_type = type;
    popup_id = id;
    select = [];

    // получаем список файлов и информацию о них в пользовательской директории
    get_user_files();
    
    var inhtml = ''; // область для вставки блоков из шаблонов файла или изображения для выбора
    
    // заполняем inhtml
    for (i = 0; i < data_user_files.result.length; i++) {
        var is = 0;
        for (j = 0; j < adding.length; j++) {
            if (data_user_files.result[i].id == adding[j]) {is = 1; break;}
        }
        if (!is) { 
            // кандидат на добавление
            if ( ( type == 'posters' || type == 'shots' ) && data_user_files.result[i].type == 'image' ) {
                var tmp = tmpl_modal_image;
                tmp = tmp.replace( /%ID%/g,   data_user_files.result[i].id );
                tmp = tmp.replace( /%NAME%/g, data_user_files.result[i].name );
                tmp = tmp.replace( /%URL%/g,  data_user_files.result[i].url );
                tmp = tmp.replace( /%SIZE%/g, size_to_str(data_user_files.result[i].size) );
                inhtml += tmp;
            }
            else if ( type == 'files' ) {
                var tmp = tmpl_modal_file;
                tmp = tmp.replace( /%ID%/g,   data_user_files.result[i].id );
                tmp = tmp.replace( /%NAME%/g, data_user_files.result[i].name );
                tmp = tmp.replace( /%URL%/g,  data_user_files.result[i].url );
                tmp = tmp.replace( /%SIZE%/g, size_to_str(data_user_files.result[i].size) );
                inhtml += tmp;
            }
            else if ( type == 'subtitles' && data_user_files.result[i].type == 'subtitle' ) {
                var tmp = tmpl_modal_file;
                tmp = tmp.replace( /%ID%/g,   data_user_files.result[i].id );
                tmp = tmp.replace( /%NAME%/g, data_user_files.result[i].name );
                tmp = tmp.replace( /%URL%/g,  data_user_files.result[i].url );
                tmp = tmp.replace( /%SIZE%/g, size_to_str(data_user_files.result[i].size) );
                inhtml += tmp;
            }
        }
    }

    // выводим popup окошко
    $("#myModalBox").modal('show');
    $("#myModalBoxProcessBody").html(inhtml);
}

// функции выбора или отмены выбора в popup окне
function modal_select(id) {
    // проходимся по массиву выбранных и ищем наш файл, чтобы понять был ли он уже выбран
    var is = 0;
    for (i = 0; i < select.length; i++) {
        if (select[i] == id) {
            is = 1;
            // файл найден среди выбранных, значит это запрос на удаление из выбранных, поэтому убираем его из массива
            select[i] = '';
            break;
        }
    }
    
    // определяемся с именем идентификатора объекта и находим его
    var obj = 'popup-files-' + id;
    if (popup_type == 'posters' || popup_type == 'shots') {obj = 'popup-images-' + id;}
    obj = document.getElementById(obj);
    
    // меняем
    if (is) {
        // файл был выбран, нужно убрать выделение
        obj.style.backgroundColor = 'white';
    }
    else {
        // файл не был выбран, нужно выделить
        select.push(id);
        obj.style.backgroundColor = 'whitesmoke';
    }
}

// функции принятия выбора в popup окне
var token = '';
var myloadid = '';
function modal_select_go(loading_id) {
    myloadid = loading_id;

    // получаем токен
    token = generate_token(40);

    // инициализация структуры для отправки
    var tmp = {};
    tmp.file_command  = 'create';
    tmp.group_id      = data_info.group_id;
    tmp.create_data   = [];

    // проходимся по массиву выделенных файлов и добавляем их в нужные структуры
    for (i = 0; i < select.length; i++) {
        var data = {};
        data.type = popup_type;
        data.file = id_to_name[select[i]];
        if (popup_type == 'subtitles') { data.parent_id = popup_id; data.type = 'files'; }
        tmp.create_data.push(data);
    }
    
    // loading open
    $("#" + myloadid).css('display','inline-block');
    
    var str = JSON.stringify(tmp);
    $.ajax({
        type: 'POST',
        data: ({ "json" : str, "token" : token }),
        async: true,
        url: '/edit',
        timeout : 10000,
        success: function (data, textStatus) {
            $("#" + myloadid).css('display','none'); // loading close
        
            var data = JSON.parse(data);
            if (data.error) {
                $("#myModalBoxProcessBodyStatus").html(data.error);
                return false;
            }

            // проходимся по всем полученным структурам и добавляем их в нашу основную структуру data_info
            if (data.posters) {
                for (i = 0; i < data.posters.length; i++) { data_info.posters.push(data.posters[i]); }
            }

            if (data.shots) {
                for (i = 0; i < data.shots.length; i++) { data_info.shots.push(data.shots[i]); }
            }
            
            if (data.files) {
                for (i = 0; i < data.files.length; i++) { data_info.files.push(data.files[i]); }
            }   
            
            if (data.depends) {
                for (i = 0; i < data.depends.length; i++) { data_info.subtitles.push(data.depends[i]); }
            }   

            // перезагружаем отображение добавленных файлов
            reload_files_from_data_info();
    
            // закрываем модальное окно выбора
            $('#myModalBox').modal('hide');
            
            // зоново получаем список файлов в директории пользователя
            get_user_files();
        },
        error: function (jqXHR, exception) {
           if (exception == 'timeout') {
               // если превысили ожидание
               modal_select_go_proccess();
               return;
           }

           // другие ошибки
           $("#" + myloadid).css('display','none'); // loading close
           
           var mess = ajax_fail(jqXHR, exception);
           $("#myModalBoxProcessBodyStatus").html(mess);
        }
    });
}

// функция ожидания результата отправки данных на сервер
var modal_select_go_proccess = function() {
    // отправляем
    $.ajax({
        type: 'POST',
        data: ({ "token" : token }),
        async: true,
        url: '/token',
        timeout : 3000,
        success: function (data, textStatus) {
            var data = JSON.parse(data);
            if (data.error) {
                $("#" + myloadid).css('display','none'); // loading close
                $("#myModalBoxProcessBodyStatus").html(data.error);
                return false;
            }
            
            if ( data.result !== undefined ) {
                // создалось
                location.reload();
                return;
            }
            
            if ( data.process !== undefined ) {
                // в процессе
                $("#myModalBoxProcessBodyStatus").html(data.process);
                sleep(3000, modal_select_go_proccess);
                return;
            }
        },
        error: function (jqXHR, exception) {
           if (exception == 'timeout') {
               // если превысили ожидание
               sleep(3000, modal_select_go_proccess);
               return;
           }

           // другие ошибки
           $("#" + myloadid).css('display','none'); // loading close
           var mess = ajax_fail(jqXHR, exception);
           $("#myModalBoxProcessBodyStatus").html(mess);
        }
        
   });
}





// заполняем поля в зависимости от данных в кеше
function reload_files_from_data_info() {

    // отображаем постеры
    for (i = 0; i < data_info.posters.length; i++) {
        // должно быть добавлено
        create_all_inb_files( i, 'posters' );
    }
    
    // отображаем кадры
    for (i = 0; i < data_info.shots.length; i++) {
        // должно быть добавлено
        create_all_inb_files( i, 'shots' );
    }

    // отображаем файлы
    for (i = 0; i < data_info.files.length; i++) {
        // должно быть добавлено
        create_all_inb_files( i, 'files' );
    }
    
    // отображаем субтитры
    for (i = 0; i < data_info.subtitles.length; i++) {
        create_all_inb_files( i, 'subtitles' );
    }

}

// функция добавляем области с файлом, можно указать все, либо кроме какой-то категории
function create_all_inb_files( num, cat) {
    var tmp_inb;

    if (cat == 'posters') {
        // добавляем в постеры
        // проверяем, нет ли уже добавленной области с этим файлом в постерах
        tmp_inb = document.getElementById('posters-file-body-' + data_info.posters[num].id);
        if (!tmp_inb) {
            // области нет, нужно добавить
            var tmp = tmpl_posters;
            tmp = tmp.replace( /%ID%/g, data_info.posters[num].id );
            tmp = tmp.replace( /%NAME%/g, data_info.posters[num].file );
            tmp = tmp.replace( /%URL%/g,  data_info.posters[num].url );
            tmp = tmp.replace( /%SIZE%/g, size_to_str(data_info.posters[num].size) );
            $(inb_posters_data).append(tmp); // добавляем в DOM
        }
    }
    else if (cat == 'shots') {
        tmp_inb = document.getElementById('shots-file-body-' + data_info.shots[num].id);
        if (!tmp_inb) {
            // области нет, нужно добавить
            var tmp = tmpl_shots;
            tmp = tmp.replace( /%ID%/g, data_info.shots[num].id );
            tmp = tmp.replace( /%NAME%/g, data_info.shots[num].file );
            tmp = tmp.replace( /%URL%/g,  data_info.shots[num].url );
            tmp = tmp.replace( /%SIZE%/g, size_to_str(data_info.shots[num].size) );
            $(inb_shots_data).append(tmp); // добавляем в DOM
        }
    }
    else if (cat == 'files') {
        tmp_inb = document.getElementById('files-file-body-' + data_info.files[num].id);
        if (!tmp_inb) {
            // области нет, нужно добавить
            var tmp = tmpl_files;
            tmp = tmp.replace( /%ID%/g, data_info.files[num].id );
            tmp = tmp.replace( /%NAME%/g, data_info.files[num].file );
            tmp = tmp.replace( /%URL%/g,  data_info.files[num].url );
            tmp = tmp.replace( /%SIZE%/g, size_to_str(data_info.files[num].size) );
            // значения в полях формы
            // название
            tmp = tmp.replace( /%VALUE%/g,  data_info.files[num].title );
            $(inb_files_data).append(tmp); // добавляем в DOM
            
            // тип (вставляться должен после append)
            if      (data_info.files[num].type == 0) {$('#form-type-' + data_info.files[num].id + ' option[value=0]').attr('selected', 'selected');}
            else if (data_info.files[num].type == 1) {$('#form-type-' + data_info.files[num].id + ' option[value=1]').attr('selected', 'selected');}
        }
    }
    else if (cat == 'subtitles') {
        var tmp_inb = document.getElementById('subtitles-file-body-'  + data_info.subtitles[num].id + '-' + data_info.subtitles[num].parent_id);
        if (!tmp_inb) {
            // области нет, нужно добавить
            // находим область вставки для субтитров в этом конкретном файле
            var tmp_inb_parent = document.getElementById('files-file-body-subtitles-' + data_info.subtitles[num].parent_id);
            if (tmp_inb_parent) {
                var tmp = tmpl_subtitles;
                tmp = tmp.replace( /%ID%/g, data_info.subtitles[num].id );
                tmp = tmp.replace( /%NAME%/g, data_info.subtitles[num].file );
                tmp = tmp.replace( /%PARENT_ID%/g, data_info.subtitles[num].parent_id );
                tmp = tmp.replace( /%URL%/g,  data_info.subtitles[num].url );
                tmp = tmp.replace( /%SIZE%/g, size_to_str(data_info.subtitles[num].size) );
                // значения в полях формы
                tmp = tmp.replace( /%VALUE%/g,  data_info.subtitles[num].title );
                $(tmp_inb_parent).append(tmp); // добавляем в DOM
            }
        }
    }

}

// функция удаляет выбранность какого либо файла
function delete_all_inb_files( id, type ) {
    var is = 0;
    var num = 0;

    if ( type == 'posters' ) {
        // проходимся по постерам и смотрим, есть ли такой
        for (i = 0; i < data_info.posters.length; i++) { if (data_info.posters[i].id == id) {is = 1; num = i; break;} }
    }
    else if ( type == 'shots' ) {
        // проходимся по постерам и смотрим, есть ли такой
        for (i = 0; i < data_info.shots.length; i++) { if (data_info.shots[i].id == id) {is = 1; num = i; break;} }
    }
    else if ( type == 'files' ) {
        // проходимся по постерам и смотрим, есть ли такой
        for (i = 0; i < data_info.files.length; i++) { if (data_info.files[i].id == id) {is = 1; num = i; break;} }
    }
    else if ( type == 'subtitles' ) {
        // проходимся по постерам и смотрим, есть ли такой
        for (i = 0; i < data_info.subtitles.length; i++) { if (data_info.subtitles[i].id == id) {is = 1; num = i; break;} }
    }
    
    if (! is) {return;}
    
    // делаем запрос на удаление
    var tmp = {};
    tmp.file_command  = 'delete';
    tmp.file_id       = id;
    tmp.file_type     = type;
    tmp.group_id      = data_info.group_id;
    var str = JSON.stringify(tmp);
    $.ajax({
        type: 'POST',
        data: ({ "json" : str }),
        async: true,
        url: '/edit',
        success: function (data, textStatus) {
            var data = JSON.parse(data);
            if (data.error) { alert('Ошибка: ' + data.error); return false; }
            
            // удаляем из DOM

            if ( type == 'posters' ) {
                // постеры
                data_info.posters[num] = ''; data_info.posters = $.grep(data_info.posters, function(el){return el != ''});
                var tmp_inb = document.getElementById('posters-file-body-' + id);
                if (tmp_inb) {RemoveElem(tmp_inb);}
            }   
            else if ( type == 'shots' ) {
                // кадры
                data_info.shots[num] = ''; data_info.shots = $.grep(data_info.shots, function(el){return el != ''});
                var tmp_inb = document.getElementById('shots-file-body-' + id);
                if (tmp_inb) {RemoveElem(tmp_inb);}
            }
            else if ( type == 'files' ) {
                // файлы
                // удаляем привязанные файлы
                for (i = 0; i < data_info.subtitles.length; i++) {
                    if (data_info.subtitles[i].parent_id == id) {delete_all_inb_files(data_info.subtitles[i].id);}
                }
        
                // удаляем файл
                data_info.files[num] = ''; data_info.files = $.grep(data_info.files, function(el){return el != ''});
                var tmp_inb = document.getElementById('files-file-body-' + id);
                if (tmp_inb) {RemoveElem(tmp_inb);}
            }
            else if ( type == 'subtitles' ) {
                // субтитры
                var tmp_inb = document.getElementById('subtitles-file-body-'  + id + '-' + data_info.subtitles[num].parent_id);
                if (tmp_inb) {RemoveElem(tmp_inb);}
                data_info.subtitles[num] = ''; data_info.subtitles = $.grep(data_info.subtitles, function(el){return el != ''});
            }
        }               
   });
}

function get_user_files() {
    // чистим кеш
    id_to_name = {};

    $.ajax({
        async: false,
        url: '/get-user-files?rnd=' + Math.round(Math.random()*1000000),
        success: function (data, textStatus) {
            data_user_files = JSON.parse(data);
            if (data_user_files.error) {alert(data_user_files.error); return false;}
            else {
                // проводим вычисления хэшей файлов
                for (i = 0; i < data_user_files.result.length; i++) {
                    id_to_name[data_user_files.result[i].id] = data_user_files.result[i].name;
                }
            }
        }               
   });

}

function save_data_info_to_cookie() {
    // сохраняем данные в cookie
    var str = JSON.stringify(data_info);
    document.cookie = 'data_add=' + str + '; expires=01/01/2099 00:00:00';
}

function get_data_info_from_json() {
    // извлекаем сохраненные данные из json
    var str = data_json;
    
    if (str) {
        data_info = JSON.parse(str);
    }
    
    // инициализация нужных структур
    if (data_info.posters   === undefined) {data_info.posters   = {};}
    if (data_info.shots     === undefined) {data_info.shots     = {};}
    if (data_info.files     === undefined) {data_info.files     = {};}
    if (data_info.subtitles === undefined) {data_info.subtitles = {};}
    if (data_info.countries === undefined) {data_info.countries = [];}
    if (data_info.genres    === undefined) {data_info.genres    = [];}
}

function file_form_modify( type, act, id, val )  {
    // изменяем данные по файлам
    if (type == 'files') {
        for (i = 0; i < data_info.files.length; i++) {
            if (data_info.files[i].id == id) {
                var tmp = data_info.files[i];
                tmp[act] = val;
                break;
            } 
        }
    }
    else if (type == 'subtitles') {
        for (i = 0; i < data_info.subtitles.length; i++) {
            if (data_info.subtitles[i].id == id) {
                var tmp = data_info.subtitles[i];
                tmp[act] = val;
                break;
            } 
        }
    }
    
    // делаем запрос на изменение
    var tmp = {};
    tmp.file_command  = 'edit';
    tmp.file_id       = id;
    tmp.file_action   = act;
    tmp.file_value    = val;
    tmp.group_id      = data_info.group_id;
    var str = JSON.stringify(tmp);
    $.ajax({
        type: 'POST',
        data: ({ "json" : str }),
        async: true,
        url: '/edit',
        success: function (data, textStatus) {
            var data = JSON.parse(data);
            if (data.error) { alert('Ошибка: ' + data.error); return false; }
        }
   });
}

function users_file_delete(id) {
    $.ajax({
        type: 'POST',
        data: ({ "file" : id_to_name[id] }),
        async: true,
        url: '/get-user-files',
        success: function (data, textStatus) {
            var data = JSON.parse(data);
            if (data.error) { alert('Ошибка: ' + data.error); return false; }
            // проходимся по массиву с пользовательскими файлами и удаляем его
            for (j = 0; j < data_user_files.result.length; j++) {
                if (data_user_files.result[j].name == id_to_name[id]) {
                    delete data_user_files.result[j];
                    data_user_files.result[j] = '';
                    data_user_files.result = $.grep(data_user_files.result, function(el){return el != ''});
                    break;
                }
            }
            // сбрасываем выбранные файлы
            select = [];
            
            // обновляем окно выбора
            modal_choose_files( popup_type, popup_id );
        }               
   });
}

function delete_group() {
    // удаление объекта группы
    var tmp = {};
    tmp.file_command  = 'delete_group';
    tmp.group_id      = data_info.group_id;
    var str = JSON.stringify(tmp);
    $.ajax({
        type: 'POST',
        data: ({ "json" : str }),
        async: true,
        url: '/edit',
        success: function (data, textStatus) {
            var data = JSON.parse(data);
            if (data.error) { alert('Ошибка: ' + data.error); return false; }
            location.reload();
        }
   });
}

var conv_setting_id = 0;
function get_conv_setting(file_id) {
    conv_setting_id = file_id;
    $.ajax({
        async: true,
        url: '/get-file-conv-setting?rnd=' + Math.round(Math.random()*1000000) + '&file_id=' + file_id,
        success: function (data, textStatus) {
            var conv_setting = JSON.parse(data);
            if (conv_setting.error) {alert(conv_setting.error); return false;}
            
            $("#myModalBoxSetConv").modal('show');
            var inhtml = $("#TmplConvSetting").html();
            $("#myModalBoxSetConvBody").html(inhtml);

            if (typeof conv_setting.file             !== 'undefined') {$("#conv-set-file").html(conv_setting.file);} 
            if (typeof conv_setting.video_map        !== 'undefined') {$("#conv-set-video-map").html(conv_setting.video_map);}
            if (typeof conv_setting.video_codec      !== 'undefined') {$("#conv-set-video-codec").html(conv_setting.video_codec);}
            if (typeof conv_setting.video_resolution !== 'undefined') {$("#conv-set-video-resolution").html(conv_setting.video_resolution);}
            if (typeof conv_setting.video_bitrate    !== 'undefined') {$("#conv-set-video-bitrate").html(conv_setting.video_bitrate);}
            if (typeof conv_setting.video_duration   !== 'undefined') {$("#conv-set-video-duration").html(conv_setting.video_duration);}
            if (typeof conv_setting.audio_map        !== 'undefined') {$("#conv-set-audio-map").html(conv_setting.audio_map);}
            if (typeof conv_setting.audio_codec      !== 'undefined') {$("#conv-set-audio-codec").html(conv_setting.audio_codec);}
            
            
            $("#conv-set-conv-b").val(conv_setting.conv_b);
            $("#conv-set-conv-async").val(conv_setting.conv_async);
            $("#conv-set-conv-af").val(conv_setting.conv_af);
            $("#conv-set-conv-s").val(conv_setting.conv_s);
            $("#conv-set-conv-ss").val(conv_setting.conv_ss);
            $("#conv-set-conv-t").val(conv_setting.conv_t);
            
            for (i = 0; i < conv_setting.audio_track.length; i++) {
                var tmp = '<option value="' + conv_setting.audio_track[i].id + '"';
                if ( conv_setting.audio_track[i].id == conv_setting.audio_map ) {
                    tmp = tmp + ' selected';
                }
                tmp = tmp + '>' + conv_setting.audio_track[i].title + '</option>';
                $("#conv-set-conv-map").append( $(tmp));
            }
            if (typeof conv_setting.conv_map !== 'undefined') {$("#conv-set-conv-map").val(conv_setting.conv_map);}

            if (typeof conv_setting.conv_status !== 'undefined') {
                if (!conv_setting.conv_status) {conv_setting.conv_status = 'первоначальное заполнение';}
                else if (conv_setting.conv_status == '1') {conv_setting.conv_status = 'ожидает конвертации';}
                else if (conv_setting.conv_status == '2') {conv_setting.conv_status = 'конвертация выполнена';}
                else if (conv_setting.conv_status == '3') {
                    conv_setting.conv_status = 'происходит конвертация';
                    $("#conv-set-conv-map").prop('disabled', true);
                    $("#conv-set-conv-b").prop('disabled', true);
                    $("#conv-set-conv-async").prop('disabled', true);
                    $("#conv-set-conv-af").prop('disabled', true);
                    $("#conv-set-conv-s").prop('disabled', true);
                    $("#conv-set-conv-ss").prop('disabled', true);
                    $("#conv-set-conv-t").prop('disabled', true);
                    $("#conv-set-apply").prop('disabled', true);
                }
            }
            else {
                conv_setting.conv_status = 'первоначальное заполнение';
            }
            $("#conv-set-conv-status").html(conv_setting.conv_status);
        }               
   });
}

function modal_save_conv_setting() {
    if (!conv_setting_id) {alert('не указан file_id');}
    
    var tmp = {};
    
    tmp.file_id = conv_setting_id;
    tmp.map     = $("#conv-set-conv-map").val();
    tmp.b       = $("#conv-set-conv-b").val();
    tmp.async   = $("#conv-set-conv-async").val();
    tmp.af      = $("#conv-set-conv-af").val();
    tmp.s       = $("#conv-set-conv-s").val();
    tmp.ss      = $("#conv-set-conv-ss").val();
    tmp.t       = $("#conv-set-conv-t").val();
    
    var str = JSON.stringify(tmp);
    $.ajax({
        type: 'POST',
        data: ({ "json" : str }),
        async: true,
        url: '/get-file-conv-setting',
        success: function (data, textStatus) {
            var data = JSON.parse(data);
            if (data.error) { alert('Ошибка: ' + data.error); return false; }
            // закрываем модальное окно выбора
            $('#myModalBoxSetConv').modal('hide');
        }
   });
}

function modal_create_shots(group_id, loading_id) {
    // делаем запрос на автоматическое создание кадров
    $("#" + loading_id).css('display','inline-block');
    $.ajax({
        type: 'POST',
        data: ({ "group_id" : group_id }),
        async: true,
        url: '/create-shots',
        success: function (data, textStatus) {
            location.reload();
        },
        error: function (jqXHR, exception) {
           var mess = ajax_fail(jqXHR, exception);
           $("#" + loading_id).css('display','none');
           alert(mess);
        }
   });
}