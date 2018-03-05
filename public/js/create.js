var tmpl_posters     = document.getElementById('TmplDataPosters').innerHTML;
var tmpl_shots       = document.getElementById('TmplDataShots').innerHTML;
var tmpl_files       = document.getElementById('TmplDataFiles').innerHTML;
var tmpl_subtitles   = document.getElementById('TmplDataSubtitle').innerHTML;
var tmpl_modal_image = document.getElementById('TmplModalImage').innerHTML;
var tmpl_modal_file  = document.getElementById('TmplModalFile').innerHTML;
var tmpl_elem_countries = document.getElementById('TmplElemCountries').innerHTML;
var tmpl_elem_genres    = document.getElementById('TmplElemGenres').innerHTML;

var adding          = []; // хранит имена файлов отображенных на странице
var select          = []; // хранит имена файлов выбранных в popup окне
var data_info       = {}; // структура данных для добавления
var data_user_files = {}; // структура файлов, находящихся в директории пользователя
var id_to_name      = {}; // структура хранения идентификаторов и названий файлов для быстрого поиска

// поиск областей в DOM для дальнейшего использования
var inb_form_val_kinopoisk      = document.getElementById('form-kinopoisk-id');
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
// получаем сохраненную структуру из cookie
get_data_info_to_cookie();
// из структуры заполняем общую информацию
reload_total_info();
// из структуры формируем отображение файлов
reload_files_from_data_info();


// функция отправки данных на сервер
var token = '';
var myloadid = '';
function send_info(loading_id) {
    myloadid = loading_id;

    // получаем токен
    token = generate_token(40);

    // формируем json строку и выводим окно
    var str = JSON.stringify(data_info);
    $("#myModalBoxProcess").modal('show');
    
    // loading open
    $("#" + myloadid).css('display','inline-block');
    
    // отправляем
    $.ajax({
        type: 'POST',
        data: ({ "json" : str, "token" : token }),
        async: true,
        url: '/create',
        timeout : 10000,
        success: function (data, textStatus) {
            $("#" + myloadid).css('display','none'); // loading close
            
            var data = JSON.parse(data);
            if (data.error) {
                $("#myModalBoxProcessBody").html(data.error);
                return false;
            }
            
            if ( data.result !== undefined ) {
                var tmpl = document.getElementById('Success').innerHTML;
                tmpl = tmpl.replace( /%GROUP_ID%/g, data.result );
                $("#myModalBoxProcessBody").html(tmpl);
                clear_info();
            }

        },
        error: function (jqXHR, exception) {
           if (exception == 'timeout') {
               // если превысили ожидание
               send_info_process(loading_id);
               return;
           }

           // другие ошибки
           $("#" + myloadid).css('display','none'); // loading close
           
           var mess = ajax_fail(jqXHR, exception);
           $("#myModalBoxProcessBody").html(mess);
        }
        
   });
}

// функция ожидания результата отправки данных на сервер
var send_info_process = function() {
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
                $("#myModalBoxProcessBody").html(data.error);
                return false;
            }
            
            if ( data.result !== undefined ) {
                // создалось
                $("#" + myloadid).css('display','none'); // loading close
                var tmpl = document.getElementById('Success').innerHTML;
                tmpl = tmpl.replace( /%GROUP_ID%/g, data.result );
                $("#myModalBoxProcessBody").html(tmpl);
                clear_info();
                return;
            }
            
            if ( data.process !== undefined ) {
                // в процессе
                $("#myModalBoxProcessBody").html(data.process);
                sleep(3000, send_info_process);
                return;
            }
        },
        error: function (jqXHR, exception) {
           if (exception == 'timeout') {
               // если превысили ожидание
               sleep(3000, send_info_process);
               return;
           }

           // другие ошибки
           $("#" + myloadid).css('display','none'); // loading close
           var mess = ajax_fail(jqXHR, exception);
           $("#myModalBoxProcessBody").html(mess);
        }
        
   });
}



// функция очистки данных
function clear_info() {
    // очищаем
    adding          = [];
    select          = [];
    data_info       = {};
    
    // сохраняем данные в cookie
    save_data_info_to_cookie();
    
    // заново генерируем
    reload_total_info();
    inb_posters_data.innerHTML = '';
    inb_shots_data.innerHTML = '';
    inb_files_data.innerHTML = '';
    
    // инициализация нужных структур
    if (data_info.posters   === undefined) {data_info.posters   = {};}
    if (data_info.shots     === undefined) {data_info.shots     = {};}
    if (data_info.files     === undefined) {data_info.files     = {};}
    if (data_info.subtitles === undefined) {data_info.subtitles = {};}
    if (data_info.countries === undefined) {data_info.countries = [];}
    if (data_info.genres    === undefined) {data_info.genres    = [];}
    
    // чистим html
    $("#data-countries-body").html('');
    $("#data-genres-body").html('');
}

// функция установки общей информации из структуры
function reload_total_info() {
    if (data_info.kinopoisk)   { inb_form_val_kinopoisk.value   = data_info.kinopoisk;   } else { inb_form_val_kinopoisk.value   = ''; }
    if (data_info.title)       { inb_form_val_title.value       = data_info.title;       } else { inb_form_val_title.value       = ''; }
    if (data_info.title_orig)  { inb_form_val_title_orig.value  = data_info.title_orig;  } else { inb_form_val_title_orig.value  = ''; }
    if (data_info.year)        { inb_form_val_year.value        = data_info.year;        } else { inb_form_val_year.value        = 0; }
    if (data_info.allow_age)   { inb_form_val_allow_age.value   = data_info.allow_age;   } else { inb_form_val_allow_age.value   = -1; }
    if (data_info.is_serial)   { inb_form_val_is_serial.value   = data_info.is_serial;   } else { inb_form_val_is_serial.value   = 0; }
    if (data_info.description) { inb_form_val_description.value = data_info.description; } else { inb_form_val_description.value = ''; }
    
    // страны
    $("#data-countries-body").html("");
    var etalon = JSON.parse(countries_json);
    if (data_info.countries) {
        for (i = 0; i < data_info.countries.length; i++) {
            var tmpl = tmpl_elem_countries;
            tmpl = tmpl.replace( /%ID%/g, data_info.countries[i] );
            tmpl = tmpl.replace( /%TITLE%/g, etalon[data_info.countries[i]]);
            $("#data-countries-body").append(tmpl);
            $(inb_form_val_countries).val('');
        }
    }
    
    // жанры
    $("#data-genres-body").html("");
    var etalon = JSON.parse(genres_json);
    if (data_info.genres) {
        for (i = 0; i < data_info.genres.length; i++) {
            var tmpl = tmpl_elem_genres;
            tmpl = tmpl.replace( /%ID%/g, data_info.genres[i] );
            tmpl = tmpl.replace( /%TITLE%/g, etalon[data_info.genres[i]]);
            $("#data-genres-body").append(tmpl);
            $(inb_form_val_genres).val('');
        }
    }
}

// функция сохранения изменений общей информации в структуре
function save_total_info( type, val ) {
    data_info[type] = val;
    save_data_info_to_cookie();
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
    
    // сохраняем в cookie
    save_data_info_to_cookie();
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
    
    // сохраняем в cookie
    save_data_info_to_cookie();
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
            if ( ( type == 'poster' || type == 'shots' ) && data_user_files.result[i].type == 'image' ) {
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
    $("#choose-modal-body").html(inhtml);
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
    if (popup_type == 'poster' || popup_type == 'shots') {obj = 'popup-images-' + id;}
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
function modal_select_go() {
    // проходимся по массиву выделенных файлов и добавляем их в нужные структуры
    for (i = 0; i < select.length; i++) {
        if (popup_type == 'poster') {
            data_info.posters[id_to_name[select[i]]] = {};
        }
        else if (popup_type == 'shots') {
            data_info.shots[id_to_name[select[i]]] = {};
        }
        else if (popup_type == 'files') {
            data_info.files[id_to_name[select[i]]] = {};
        }
        else if (popup_type == 'subtitles') {
            data_info.subtitles[id_to_name[select[i]]] = {};
            data_info.subtitles[id_to_name[select[i]]].parent = id_to_name[popup_id];
        }
    }
    
    // сохраняем данные в cookie
    save_data_info_to_cookie();
    
    // перезагружаем отображение добавленных файлов
    reload_files_from_data_info();
    
    // закрываем модальное окно выбора
    $('#myModalBox').modal('hide');
}

// заполняем поля в зависимости от данных в кеше
function reload_files_from_data_info() {

    // проверяем исчезнувшие файлы
    for (i = 0; i < adding.length; i++) {
        var is = 0;
        for (j = 0; j < data_user_files.result.length; j++) {
            if (data_user_files.result[j].id == adding[i]) {is = 1; break;}
        }
        if (!is) {
            // файл был удален, удаляем упоминания о нем
            delete data_info.posters[id_to_name[adding[i]]]; 
            delete data_info.shots[id_to_name[adding[i]]];
            delete data_info.files[id_to_name[adding[i]]];
            delete data_info.subtitles[id_to_name[adding[i]]];
            delete_all_inb_files(id_to_name[adding[i]]);
        }
    }
    
    // отображаем постеры
    for( key in data_info.posters ) {
        // должно быть добавлено
        
        // проверка на внешнюю ссылку
        if ( key.search(/^http[s]*:\/\//) != -1) {
            // найдена внешняя ссылка
            id_to_name[data_info.posters[key].id] = key;
            create_all_inb_files( key, 'posters', 'image', key, 0 );
            continue;
        }
        
        // файлы в домашней директории пользователя
        for (i = 0; i < data_user_files.result.length; i++) {
            if (data_user_files.result[i].name == key) {
                create_all_inb_files( data_user_files.result[i].name, 'posters', data_user_files.result[i].type, data_user_files.result[i].url, data_user_files.result[i].size );
                break;
            }
        }
    }
    
    // отображаем кадры
    for( key in data_info.shots ) {
        // должно быть добавлено
        for (i = 0; i < data_user_files.result.length; i++) {
            if (data_user_files.result[i].name == key) {
                create_all_inb_files( data_user_files.result[i].name, 'shots', data_user_files.result[i].type, data_user_files.result[i].url, data_user_files.result[i].size );
                break;
            }
        }
    }

    // отображаем файлы
    for( key in data_info.files ) {
        // должно быть добавлено
        for (i = 0; i < data_user_files.result.length; i++) {
            if (data_user_files.result[i].name == key) {
                create_all_inb_files( data_user_files.result[i].name, 'files', data_user_files.result[i].type, data_user_files.result[i].url, data_user_files.result[i].size );
                break;
            }
        }
    }
    
    // отображаем субтитры
    for( key in data_info.subtitles ) {
        // должно быть добавлено
        for (i = 0; i < data_user_files.result.length; i++) {
            if (data_user_files.result[i].name == key) {
                create_all_inb_files( data_user_files.result[i].name, 'subtitles', data_user_files.result[i].type, data_user_files.result[i].url, data_user_files.result[i].size );
                break;
            }
        }
    }

}

// функция добавляем области с файлом, можно указать все, либо кроме какой-то категории
function create_all_inb_files( file, cat, type, url, size ) {
    var tmp_inb;
    
    // находим идентификатор файла
    var id = 0; for( key in id_to_name ) {if (id_to_name[key] == file) {id = key; break;}}

    if (cat == 'posters') {
        // добавляем в постеры
        // проверяем, нет ли уже добавленной области с этим файлом в постерах
        tmp_inb = document.getElementById('posters-file-body-' + id);
        if (!tmp_inb) {
            // области нет, нужно добавить
            var tmp = tmpl_posters;
            tmp = tmp.replace( /%ID%/g, id );
            tmp = tmp.replace( /%NAME%/g, file );
            tmp = tmp.replace( /%URL%/g,  url );
            tmp = tmp.replace( /%SIZE%/g, size_to_str(size) );
            $(inb_posters_data).append(tmp); // добавляем в DOM
            adding.push(id); // управление массивом отображенных файлов
        }
    }
    else if (cat == 'shots') {
        tmp_inb = document.getElementById('shots-file-body-' + id);
        if (!tmp_inb) {
            // области нет, нужно добавить
            var tmp = tmpl_shots;
            tmp = tmp.replace( /%ID%/g, id );
            tmp = tmp.replace( /%NAME%/g, file );
            tmp = tmp.replace( /%URL%/g,  url );
            tmp = tmp.replace( /%SIZE%/g, size_to_str(size) );
            $(inb_shots_data).append(tmp); // добавляем в DOM
            adding.push(id); // управление массивом отображенных файлов
        }
    }
    else if (cat == 'files') {
        tmp_inb = document.getElementById('files-file-body-' + id);
        if (!tmp_inb) {
            // области нет, нужно добавить
            var tmp = tmpl_files;
            tmp = tmp.replace( /%ID%/g, id );
            tmp = tmp.replace( /%NAME%/g, file );
            tmp = tmp.replace( /%URL%/g,  url );
            tmp = tmp.replace( /%SIZE%/g, size_to_str(size) );
            // значения в полях формы
            // название
            if (data_info.files[file].title) {tmp = tmp.replace( /%VALUE%/g,  data_info.files[file].title );}
            else {tmp = tmp.replace( /%VALUE%/g,  '' );}
            $(inb_files_data).append(tmp); // добавляем в DOM
            
            // тип (вставляться должен после append)
            if      (data_info.files[file].type == 0) {$('#form-type-' + id + ' option[value=0]').attr('selected', 'selected');}
            else if (data_info.files[file].type == 1) {$('#form-type-' + id + ' option[value=1]').attr('selected', 'selected');}

            adding.push(id); // управление массивом отображенных файлов
        }
    }
    else if (cat == 'subtitles') {
        var parent = data_info.subtitles[file].parent;
        
        // находим идентификатор родительского файла
        var id_parent = 0; for( key in id_to_name ) {if (id_to_name[key] == parent) {id_parent = key; break;}}
        
        var tmp_inb = document.getElementById('subtitles-file-body-'  + id + '-' + id_parent);
        if (!tmp_inb) {
            // области нет, нужно добавить
            // находим область вставки для субтитров в этом конкретном файле
            var tmp_inb_parent = document.getElementById('files-file-body-subtitles-' + id_parent);
            if (tmp_inb_parent) {
                var tmp = tmpl_subtitles;
                tmp = tmp.replace( /%ID%/g, id );
                tmp = tmp.replace( /%NAME%/g, file );
                tmp = tmp.replace( /%PARENT%/g, parent );
                tmp = tmp.replace( /%PARENT_ID%/g, id_parent );
                tmp = tmp.replace( /%URL%/g,  url );
                tmp = tmp.replace( /%SIZE%/g, size_to_str(size) );
                // значения в полях формы
                if (data_info.subtitles[file].title) {
                    tmp = tmp.replace( /%VALUE%/g,  data_info.subtitles[file].title );
                }
                else {
                    tmp = tmp.replace( /%VALUE%/g,  '' );
                }
                $(tmp_inb_parent).append(tmp); // добавляем в DOM
                adding.push(id); // управление массивом отображенных файлов
            }
        }
    }

}

// функция удаляет выбранность какого либо файла
function delete_all_inb_files(id) {
    // проходимся по нашим структурам и удаляем выбранный файл
    if (data_info.posters[id_to_name[id]]) { 
        // постеры
        delete data_info.posters[id_to_name[id]];
        var tmp_inb = document.getElementById('posters-file-body-' + id);
        if (tmp_inb) {RemoveElem(tmp_inb);}
    }   
    if (data_info.shots[id_to_name[id]]) {
        // кадры
        delete data_info.shots[id_to_name[id]];
        var tmp_inb = document.getElementById('shots-file-body-' + id);
        if (tmp_inb) {RemoveElem(tmp_inb);}
    }
    if (data_info.files[id_to_name[id]]) {
        // файлы
        // удаляем привязанные файлы
        for( key in data_info.subtitles ) {
            if (data_info.subtitles[key].parent == id_to_name[id]) {delete_all_inb_files(key);}
        }
        
        // удаляем файл
        delete data_info.files[id_to_name[id]];
        var tmp_inb = document.getElementById('files-file-body-' + id);
        if (tmp_inb) {RemoveElem(tmp_inb);}
    }
    if (data_info.subtitles[id_to_name[id]]) {
        // субтитры
        var parent = data_info.subtitles[id_to_name[id]].parent;
        delete data_info.subtitles[id_to_name[id]];
        
        // находим идентификатор родительского файла
        var id_parent = 0; for( key in id_to_name ) {if (id_to_name[key] == parent) {id_parent = key; break;}}
        
        var tmp_inb = document.getElementById('subtitles-file-body-'  + id + '-' + id_parent);
        if (tmp_inb) {RemoveElem(tmp_inb);}
    }
    
    // управление массивом отображенных файлов
    for (i = 0; i < adding.length; i++) {
        if (adding[i] == id) {adding[i] = ''; break;}
    }
    
    // убираем из массива пустые элементы
    adding = $.grep(adding, function(el){return el != ''});
    
    // сохраняем данные в cookie
    save_data_info_to_cookie();
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

function get_data_info_to_cookie() {
    // извлекаем сохраненные данные из cookie, если есть
    var str = get_cookie('data_add');
    
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
    if (type == 'files') {
        if (data_info.files[id_to_name[id]]) {
            var tmp = data_info.files[id_to_name[id]];
            tmp[act] = val;
        }
    }
    else if (type == 'subtitles') {
        if (data_info.subtitles[id_to_name[id]]) {
            var tmp = data_info.subtitles[id_to_name[id]];
            tmp[act] = val;
        }
    }
    save_data_info_to_cookie();
}

function users_file_delete(id) {
    $.ajax({
        type: 'POST',
        data: ({ "file" : id_to_name[id] }),
        async: true,
        url: '/get-user-files',
        success: function (data, textStatus) {
            var data = JSON.parse(data);
            if (data.error) {alert(data.error); return false;}
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

// пытаемся получить данные от kinopoisk.ru
function get_data_from_kinopoisk(loading_id) {

    // проверка на заполненность идентификатора
    var id = $("#form-kinopoisk-id").val();
    if (id.search(/^\d+$/) == -1) {
        alert("необходимо указать числовой идентификатор");
        return;
    }
    
    // получение строки капчи
    var rep = $("#form-kinopoisk-rep").val();
    
    // loading open
    $("#" + loading_id).css('display','inline-block');

    // отправка запроса
    $.ajax({
        type: 'POST',
        data: ({ "id" : id, "rep" : rep }),
        async: true,
        url: '/kinopoisk',
        success: function (data, textStatus) {
            // loading close
            $("#" + loading_id).css('display','none');
        
            var data = JSON.parse(data);
            if (data.error) {alert(data.error); return false;}
            
            // проверяем на требование ввести капчу
            if (data.captcha_need) {
                $("#kinopoisk-captcha-img").prop('src', data.captcha_img);
                $("#myModalBoxKinopoisk").modal('show');
                return;
            }
            else {
                // получили данные, разбираем
                $("#myModalBoxKinopoisk").modal('hide');
                data_info.title       = data.title;
                data_info.title_orig  = data.title_orig;
                data_info.year        = data.year;
                data_info.allow_age   = data.allow_age;
                data_info.description = data.description;
                data_info.is_serial   = data.is_serial;
                data_info.genres      = data.genres;
                data_info.countries   = data.countries;
                
                // постер
                
                // удаляем постеры
                for( key in data_info.posters ) {
                    for( id in id_to_name ) {
                        if ( id_to_name[id] == key ) {
                            delete_all_inb_files(id);
                            break;
                        }
                    }
                }
                // добавляем наш постер
                data_info.posters[data.posters.name] = {};
                data_info.posters[data.posters.name].id = data.posters.id;
                
                // обновляем общую информацию
                reload_total_info();
                
                // обновляем отображение файлов
                reload_files_from_data_info();
                
                // сохраняем данные в cookie
                save_data_info_to_cookie();

                return;
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
}