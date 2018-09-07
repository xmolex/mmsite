package Mmsite;
use Dancer2;
use Modern::Perl;
use Digest::MurmurHash qw(murmur_hash);
use Mmsite::Lib::Vars;
use Mmsite::Lib::Subs;
use Mmsite::Lib::Db;
use Mmsite::Lib::Members;
use Mmsite::Lib::Groups;
use Mmsite::Lib::Ffmpeg;
use Mmsite::Lib::Files;
use Mmsite::Lib::Kinopoisk;
use Mmsite::Lib::Mem;
use Mmsite::Auth_vk;
use Mmsite::Auth_pface;
use Mmsite::Exit;
use Mmsite::Groups;
use Mmsite::Files;
use Mmsite::Create;
use Mmsite::Upload;
use Mmsite::Edit;
use Mmsite::Token;
use Mmsite::Count;
use Mmsite::Search;

prefix undef;

our $VERSION = '0.2';

hook before => sub {
    # возвращаем куки в $ENV, для авторизации
    $ENV{'HTTP_COOKIE'} = request_header('Cookie');
    $ENV{'REMOTE_ADDR'} = request_header('X-Real-IP');
};

hook before_layout_render => sub {
    my ($tokens, $ref_content) = @_;
    
    # авторизация
    my $member_obj = Mmsite::Lib::Members->new();
    $tokens->{user_id}              = $member_obj->id;
    $tokens->{user_name}            = $member_obj->name;
    $tokens->{user_role}            = $member_obj->role;
    $tokens->{user_sys}             = $member_obj->auth_sys;
    $tokens->{users_sys_id}         = $member_obj->auth_sys_id;
    $tokens->{from}                 = request->path;

    # прочие переменные
    $tokens->{site_name} = $SITE_NAME;
};

# попытка указать, что пользователь просмотрел этот файл в плеере
post '/view' => sub {
    my $file_id = body_parameters->get('file_id') || return;
    return if $file_id !~ /^\d+$/;

    my $member_obj = Mmsite::Lib::Members->new();
    return unless $member_obj->id;
    
    return if $member_obj->is_subscribe($file_id);
    
    return $member_obj->view_create($file_id);
};

# пометить все файлы / снять пометку всех файлов в объекте группы как просмотренные
post '/viewall' => sub {
    my $group_id = body_parameters->get('group_id') || return;
    return '{"error":"id not found"}' if $group_id !~ /^-?\d+$/;

    my $member_obj = Mmsite::Lib::Members->new();
    return '{"error":"user no auth"}' unless $member_obj->id;
    
    my @result;
    
    if ($group_id < 0) {
        # снимаем пометки
        $group_id *= -1;
        @result = $member_obj->view_delete_all_from_group($group_id);
    }
    else {
        # устанавливаем пометки
        @result = $member_obj->view_create_all_from_group($group_id);
    }
    
    return to_json \@result;
};

# подписываем пользователя на объект группы, или удаляем подписку, если уже подписан
# возвращаем 0,1 или ''
post '/subscribe' => sub {
    my $group_id = body_parameters->get('group_id') || return;
    return if $group_id !~ /^\d+$/;

    my $member_obj = Mmsite::Lib::Members->new();
    return unless $member_obj->id;
    
    if ( $member_obj->is_subscribe($group_id) ) {
        # подписан, удаляем подписку
        return unless $member_obj->subscribe_delete($group_id);
        return "0";
    }
    else {
        # подписываем
        return $member_obj->subscribe_create($group_id);
    }
};

# получаем данные от kinopoisk.ru и отдаем их в json
post '/kinopoisk' => sub {
    my %result;

    my $id  = body_parameters->get('id');
    my $rep = body_parameters->get('rep');
    
    # проверка на id
    unless ($id) {
        $result{'error'} = 'не указан идентификатор фильма';
        return to_json \%result;
    }
    
    # проверка на авторизацию
    my $member_obj = Mmsite::Lib::Members->new();
    if ($member_obj->role < 2) {
        $result{'error'} = 'доступ запрещен';
        return to_json \%result;
    }

    # создаем объект для работы с kinopoisk.ru
    my $obj_kinopoisk = Mmsite::Lib::Kinopoisk->new($id);
    unless ($obj_kinopoisk) {
        $result{'error'} = 'не удалось инициализировать, не верный идентификатор';
        return to_json \%result;
    }
    
    # проверка на прием кода капчи
    if ($rep) {
        # передали капчу
        $obj_kinopoisk->set( 'captcha_rep', $rep );
    }
    
    # делаем запрос к kinopoisk и вытаскиваем данные
    my ( $result, $error ) = $obj_kinopoisk->get();
    unless ($result) {
        # не удалось разобрать
        $result{'error'} = $error;
        my $json = to_json \%result; on_utf8(\$json);
        return $json;
    }
    
    # обработка полученных данных
    if ( $obj_kinopoisk->captcha_need ) {
        # требуют ввести капчу
        $result{'captcha_need'} = 1;
        $result{'captcha_img'} = $obj_kinopoisk->captcha_img;
        return to_json \%result;
    }
    else {
        # данные получены
        $result{'title'}       = $obj_kinopoisk->title;
        $result{'title_orig'}  = $obj_kinopoisk->title_orig;
        $result{'description'} = $obj_kinopoisk->description;
        $result{'year'}        = $obj_kinopoisk->year;
        $result{'allow_age'}   = $obj_kinopoisk->allow_age;
        $result{'is_serial'}   = $obj_kinopoisk->is_serial;
        $result{'genres'}      = $obj_kinopoisk->genres;
        $result{'countries'}   = $obj_kinopoisk->countries;
        $result{'posters'}     = $KINOPOISK_URI_POSTER . $obj_kinopoisk->poster;
        
        # постер
        my $data = {
                         'id'   => murmur_hash( $result{'posters'} ),
                         'name' => $result{'posters'},
                         'size' => 0,
                         'type' => 'image',
                         'url'  => $result{'posters'}
        };
        $result{'posters'} = $data;

        # выводим
        my $json = to_json \%result; on_utf8(\$json);
        return $json;
    }
};

# формируем индексную страницу
get '/' => sub {
    # авторизация
    my $member_obj = Mmsite::Lib::Members->new();

    # получаем страницу и расчитываем смещение
    my $page = query_parameters->get('page') || 1;
    if ($page !~ m/^\d+$/) {$page = 1;}
    my $offset = 0;
    if ($page > 1) {$offset = $COUNT_OBJECT_ANONCE * --$page;}
    
    # получаем фильтр по жанру
    my $genre = query_parameters->get('genre') || 0;
    if ($genre) {
        # проверяем валидность идентификатора жанра
        my $is = 0;
        foreach ( keys %LIST_GENRES ) {
            if ($_ == $genre) {
                $is = 1;
                last;
            }
        }
        # если не нашли, то обнуляем
        unless ($is) {$genre = 0;}
    }
    
    my @html_anonces; # массив для хранения сгенерированного HTML анонсов
    my $anonces = 0;  # флаг, что есть сгенерированные анонсы
    
    # делаем запрос к базе и получаем идентификаторы для вывода
    my $sql;
    
    if ($genre) {
        # нужно сделать запрос с фильтром по жанру
        $sql = sql("SELECT group_id FROM groups_list WHERE group_id IN ( SELECT group_id FROM groups_genres WHERE genres_id='$genre' ) ORDER BY id DESC LIMIT $COUNT_OBJECT_ANONCE OFFSET $offset;");
    }
    else {
        # без фильтра
        $sql = sql("SELECT group_id FROM groups_list ORDER BY id DESC LIMIT $COUNT_OBJECT_ANONCE OFFSET $offset;");
    }
    
    if ($$sql[0]) {
        # данные есть
        foreach (@$sql) {
            my $group = Mmsite::Lib::Groups->new($_);
            if ($group) {
                my $tmp = $group->preview();
                
                # проверка на подписку и непросмотренные файлы
                if ( $member_obj->is_subscribe($group->id) ) {
                    if ( $member_obj->is_view_unlooked($group->id) ) {
                        $tmp =~ s/"gf-anc-one"/"gf-anc-one-unlooked"/s;
                    }
                }
                
                push @html_anonces, $tmp;
                $anonces = 1;   
            }
        }
    }
   
    # жарны
    my $meny = mem_get()->get('templ_select_meny');
    if (! $meny) {
        # нужно сформировать
        for my $key ( sort { $LIST_GENRES{$a} cmp $LIST_GENRES{$b} } keys %LIST_GENRES ) {
            my $tmp = $HTML_TEMPLATE_SELECT;
            $tmp =~ s/%ID%/$key/;
            $tmp =~ s/%TITLE%/$LIST_GENRES{$key}/;
            $meny .= $tmp;
        }
        mem_get()->add( 'templ_select_meny', $meny );
    }

    # страны
    my $countries = mem_get()->get('templ_select_countries');
    if (! $countries) {
        # нужно сформировать
        for my $key ( sort { $LIST_COUNTRIES{$a} cmp $LIST_COUNTRIES{$b} } keys %LIST_COUNTRIES ) {
            my $tmp = $HTML_TEMPLATE_SELECT;
            $tmp =~ s/%ID%/$key/;
            $tmp =~ s/%TITLE%/$LIST_COUNTRIES{$key}/;
            $countries .= $tmp;
        }
        mem_get()->add( 'templ_select_countries', $countries );
    }
    
    # года
    my $years = mem_get()->get('templ_select_years');
    if (! $years) {
        # нужно сформировать
        my( $sec, $min, $hour, $mday, $mon, $year_now ) = localtime();
        $year_now = $year_now + 1900;
        for ( reverse ( 1900..$year_now ) ) {
            my $tmp = $HTML_TEMPLATE_SELECT;
            $tmp =~ s/%ID%/$_/;
            $tmp =~ s/%TITLE%/$_/;
            $years .= $tmp;
        }
        mem_get()->add( 'templ_select_years', $years );
    }
    
    # выводим шаблон
    template 'index' => {
                            'html_anonces' => \@html_anonces,
                            'anonces'      => $anonces,
                            'meny'         => $meny,
                            'genre'        => $genre,
                            'user_role'    => $member_obj->role,
                            'years'        => $years,
                            'countries'    => $countries,
                            'title'        => 'Главная',
    };

};


get '/get-file-conv-setting' => sub {
    # авторизация
    my $member_obj = Mmsite::Lib::Members->new();
    return '{"error":"access denied"}' if $member_obj->role < 2;

    # удаление файла в пользовательской директории
    my $file_id = query_parameters->get('file_id');
    return '{"error":"file not found"}' unless $file_id;
    return '{"error":"file not found"}' if $file_id !~ m/^\d+$/;
    
    # создаем объект файла
    my $obj_file = Mmsite::Lib::Files->new($file_id);
    return '{"error":"file not found"}' unless $obj_file;
    
    # получаем данные по файлу
    $obj_file->get();
    
    # определяемся с источником (он может быть еще не добавлен, может быть добавлен и может быть уже удален)
    if ( !$obj_file->source && $obj_file->source_time > 0 ) {
        # источник был уже удален, поэтому модификация запрещена
        return '{"error":"source file for video already delete"}';
    }
    
    my $name_source;
    my $path_source;
    if ( !$obj_file->source ) {
        # источником будем считать сам файл, т.к. его еще не создали
        $path_source = $PATH_FILES . $obj_file->file;
        $name_source = $obj_file->file;
    }
    else {
        # есть источник
        $path_source = $PATH_FILES_SOURCE . $obj_file->source;
        $name_source = $obj_file->source;
    }
    
    # проверяем, подходящий ли тип у файла
    return '{"error":"file is not video"}' unless Mmsite::Lib::Ffmpeg::is_video_extension($path_source);

    # создаем объект для работы с ffmpeg
    my ( $obj_ffmpeg, $error)  = Mmsite::Lib::Ffmpeg->new($path_source);
    return '{"error":"$error"}' unless $obj_ffmpeg;
    
    # получаем информацию о файле
    $obj_ffmpeg->get();
    my $audio = $obj_ffmpeg->get_audio_track();
    
    # проходимся по массиву из аудио дорожек и создаем удобную структуру для json по дорожкам
    my @audio_result;
    foreach my $key ( sort {$a <=> $b} keys %$audio ) {
        my $title = $key;
        if ( $$audio{$key}{'title'} ) {$title .= ' title:' . $$audio{$key}{'title'};}
        if ( $$audio{$key}{'language'} ) {$title .= ' lang:' . $$audio{$key}{'language'};}
        my $tmp = {
                      'id' => $key,
                      'title' => $title
        };
        push @audio_result, $tmp;
    }
    
    # получаем настройки сжатия
    $obj_file->get_conv_setting();
    
    # создаем структуру для json
    my $hash = {
                  file             => $name_source,
                  video_map        => $obj_ffmpeg->video_track,
                  audio_map        => $obj_ffmpeg->audio_track,
                  video_codec      => $obj_ffmpeg->video_codec,
                  audio_codec      => $obj_ffmpeg->audio_codec,
                  video_bitrate    => $obj_ffmpeg->video_bitrate,
                  video_duration   => Mmsite::Lib::Ffmpeg::conv_sec_in_text($obj_ffmpeg->video_duration),
                  video_resolution => $obj_ffmpeg->video_width . 'x' . $obj_ffmpeg->video_height,
                  conv_status      => $obj_file->conv_status,
                  conv_map         => $obj_file->conv_set_map,
                  conv_b           => $obj_file->conv_set_b,
                  conv_async       => $obj_file->conv_set_async,
                  conv_af          => $obj_file->conv_set_af,
                  conv_s           => $obj_file->conv_set_s,
                  conv_ss          => $obj_file->conv_set_ss,
                  conv_t           => $obj_file->conv_set_t,
                  audio_track      => \@audio_result
    };
    
    return to_json $hash;
};


post '/get-file-conv-setting' => sub {
    # авторизация
    my $member_obj = Mmsite::Lib::Members->new();
    return '{"error":"access denied"}' if $member_obj->role < 2;
    
    my $json = body_parameters->get('json');
    return '{"error":"пустой запрос"}' unless $json;
    
    # разбираем данные
    $json = Encode::encode_utf8($json);
    my $result;
    unless ( eval { $result = from_json $json } ) {
        return '{"error":"ожидаются данные в json формате"}';
    }
    
    # получаем идентификатор файла
    return '{"error":"не указан идентификатор файла"}' unless $$result{'file_id'};

    my $obj_file = Mmsite::Lib::Files->new($$result{'file_id'});
    return '{"error":"указан не верный идентификатор файла"}' unless $obj_file;
    
    # получаем данные
    $obj_file->get_conv_setting();
    
    # проверяем на возможность изменения
    return '{"error":"файл сейчас конвертируется, продолжение невозможно"}' if $obj_file->conv_status == 3;
    
    # заполняем данные
    $obj_file->set_conv( 'conv_status',    1);
    $obj_file->set_conv( 'conv_set_map',   $$result{'map'});
    $obj_file->set_conv( 'conv_set_b',     $$result{'b'});
    $obj_file->set_conv( 'conv_set_async', $$result{'async'});
    $obj_file->set_conv( 'conv_set_af',    $$result{'af'});
    $obj_file->set_conv( 'conv_set_s',     $$result{'s'});
    $obj_file->set_conv( 'conv_set_ss',    $$result{'ss'});
    $obj_file->set_conv( 'conv_set_t',     $$result{'t'});
    
    # пробуем применить
    my ($res, $error) = $obj_file->set_conv_setting();
    return '{"error":"' . $error . '"}' unless $res;
    
    return('{"result":"1"}');
};


post '/create-shots' => sub {
    # автоматическое создание кадров с использованием системного скрипта
    # авторизация
    my $member_obj = Mmsite::Lib::Members->new();
    return '{"error":"access denied"}' if $member_obj->role < 2;
    
    # получаем идентификатор объекта группы
    my $group_id = body_parameters->get('group_id');
    
    # проверяем на валидность
    return unless $group_id;
    return if $group_id !~ m/^\d+$/;
    
    # отправляем в систему на создание
    system("$PATH_SCRIPTS/auto_shot.cgi $group_id");
    
    # т.к. нам ничего не нужно возвращать, то выходим
    return();
};

post '/get-user-files' => sub {
    # удаление файла в пользовательской директории
    # авторизация
    my $member_obj = Mmsite::Lib::Members->new();
    return '{"error":"access denied"}' if $member_obj->role < 2;
    
    my $file = body_parameters->get('file');
    return '{"error":"file not found"}' unless $file;

    # пользовательская директория
    my $path_user = $PATH_USERS . '/' . $member_obj->id . '/';
    
    # убираем из имени файла запрещенные символы
    $file =~ s!/\?\*\\!!g;
    
    # проверяем существование файла
    return '{"error":"file not found"}' unless (-f "$path_user/$file");
    
    # удаляем файл
    unlink("$path_user/$file");
    return '{"result":"1"}';
};


get '/get-user-files' => sub {
    # авторизация
    my $member_obj = Mmsite::Lib::Members->new();
    return '{"error":"access denied"}' if $member_obj->role < 2;
    
    # пользовательская директория
    my $path_user = $PATH_USERS . '/' . $member_obj->id . '/';
    
    # открываем и отдаем данные по пользовательским файлам
    opendir my ($tempdir), $path_user;
    my @file = readdir $tempdir;
    closedir $tempdir;  
    @file = grep !/^\.\.?$/, @file;
    
    my %result;
    my @result;
    
    # проходимся по всем пользовательским файлам и собираем по ним информацию
    for my $file (@file) {
        my @size = stat $path_user . $file;
        my $size = $size[7];
        
        # получаем расширение файла
        my $type = get_extension $file || 'undef';
        
        # разбираемся с типом файла
        if ($type =~ m/(jpg|jpeg|gif|png)/i) {
            $type = 'image';
        }
        elsif ( Mmsite::Lib::Ffmpeg::is_video_extension($type) ) {
            $type = 'video';
        }
        elsif ($type =~ m/(mp3)/i) {
            $type = 'audio';
        }
        elsif ( Mmsite::Lib::Ffmpeg::is_subtitle_extension($type) ) {
            $type = 'subtitle';
        }
        
        # формируем структуру JSON
        my %data = (
                         'id'   => murmur_hash($file),
                         'name' => $file,
                         'size' => $size,
                         'type' => $type,
                         'url'  => $URL_USERS_DATA . $member_obj->id . '/' . $file
        );
        
        push @result, \%data;
    }
    
    $result{'result'} = \@result;
    return to_json \%result;
};

1;
