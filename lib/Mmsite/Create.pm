package Mmsite::Create;
######################################################################################
# модуль создания нового объекта группы
######################################################################################
use Dancer2 appname => 'Mmsite';
use Modern::Perl;
use utf8;
use Encode;
use Mmsite::Lib::Vars;
use Mmsite::Lib::Subs;
use Mmsite::Lib::Members;
use Mmsite::Lib::Db;
use Mmsite::Lib::Groups;
use Mmsite::Lib::Images;
use Mmsite::Lib::Files;
use Mmsite::Lib::Kinopoisk;
use Mmsite::Lib::Token;

prefix '/create';

# форма создания нового объекта группы с файлами
get '' => sub {
    # авторизация
    my $member_obj = Mmsite::Lib::Members->new();
    redirect '/' if $member_obj->role < 2;

    # формируем необходимые структуры для javascript
    # страны
    my $countries_json = to_json \%LIST_COUNTRIES;
    my $countries;
    for my $key ( sort { $LIST_COUNTRIES{$a} cmp $LIST_COUNTRIES{$b} } keys %LIST_COUNTRIES ) {
        # заполняем
        push @$countries, {'id' => $key, 'title' => $LIST_COUNTRIES{$key} };
    }
    
    # жанры
    my $genres_json = to_json \%LIST_GENRES;
    my $genres;
    for my $key ( sort { $LIST_GENRES{$a} cmp $LIST_GENRES{$b} } keys %LIST_GENRES ) {
        # заполняем
        push @$genres, {'id' => $key, 'title' => $LIST_GENRES{$key} };
    }
    
    # перевод
    my $translates_json = to_json \%LIST_TRANSLATE;
    
    # разрешенный возраст
    my $allow_age_json = to_json \%ALLOW_AGE;
    my $allow_ages;
    for my $key ( sort { $a <=> $b } keys %ALLOW_AGE ) {
        # заполняем
        push @$allow_ages, {'id' => $key, 'title' => $ALLOW_AGE{$key} };
    }
    
    # год
    my $years;
    my( $sec, $min, $hour, $mday, $mon, $year_now ) = localtime();
    $year_now = $year_now + 1900;
    # заполняем года с 1900 по текущий
    push @$years, {'id' => $_, 'title' => $_ } for reverse ( 1900..$year_now );

    # выводим
    template 'group_create' => {
                                     'countries_json'  => $countries_json,
                                     'countries'       => $countries,
                                     'genres_json'     => $genres_json,
                                     'genres'          => $genres,
                                     'translates_json' => $translates_json,
                                     'allow_age_json'  => $allow_age_json,
                                     'allow_ages'      => $allow_ages,
                                     'years'           => $years,
                                     'title'           => 'Добавление',
                               };
};

# добавляем новый объект группы
post '' => sub {
    # авторизация
    my $member_obj = Mmsite::Lib::Members->new();
    return '{"error": "access denied"}' if $member_obj->role < 2;

    my $token = body_parameters->get('token');
    return '{"error": "empty token"}' unless $token;
    
    my $json = body_parameters->get('json');
    return '{"error": "empty request"}' unless $json;
    
    # добавление
    my %hash;
    
    # разбираем данные
    $json = Encode::encode_utf8($json);
    my $result;
    unless ( eval { $result = from_json $json } ) {
        return '{"error": "need json data"}';
    }
    
    # данные получены в json, производим обработку и проверяем на требования
    
    # получаем список файлов в пользовательской директории
    my $path_user = $PATH_USERS . '/' . $member_obj->id . '/';
    opendir my ($tempdir), $path_user;
    my @file = readdir $tempdir;
    closedir $tempdir;  
    @file = grep !/^\.\.?$/, @file;
    
    # проверяем на существование
    my ( $link, $ok, $err_file );
    
    # постеры
    $link = $$result{'posters'};
    ( $ok, $err_file ) =  _file_exists_and_uniq_in_user_dir( \@file, $link );
    return('{"error": "постеры: файл ' . $err_file . ' не обнаружен в вашей директории на сервере, либо он был указан более одного раза"}') unless $ok;
    
    # кадры
    $link = $$result{'shots'};
    ( $ok, $err_file ) =  _file_exists_and_uniq_in_user_dir( \@file, $link );
    return('{"error": "кадры: файл ' . $err_file . ' не обнаружен в вашей директории на сервере, либо он был указан более одного раза"}') unless $ok;
    
    # файлы
    $link = $$result{'files'};
    ( $ok, $err_file ) =  _file_exists_and_uniq_in_user_dir( \@file, $link );
    return('{"error": "файлы: файл ' . $err_file . ' не обнаружен в вашей директории на сервере, либо он был указан более одного раза"}') unless $ok;

    # субтитры
    $link = $$result{'subtitles'};
    ( $ok, $err_file ) =  _file_exists_and_uniq_in_user_dir( \@file, $link );
    return('{"error": "субтитры: файл ' . $err_file . ' не обнаружен в вашей директории на сервере, либо он был указан более одного раза"}') unless $ok;
    
    # объявление переменных общей информации
    my $kinopoisk   = 0;
    my $title       = 'unknown';
    my $title_orig  = '';
    my $year        = 0;
    my $allow_age   = -1; # т.к. 0 для этой переменной несет смысл, за NULL примем -1
    my $description = '';
    my $is_serial   = 0;
    
    # проверки по общей информации
    return '{"error": "идентификатор на kinopoisk.ru должен содержать только цифры"}' if $$result{'kinopoisk'} !~ m/^\d+$/;
    
    $kinopoisk = $$result{'kinopoisk'};
    my $sql = sql("SELECT id FROM groups_data WHERE kinopoisk_id='$kinopoisk';");
    return '{"error": "на сервере уже существует файл с таким идентификатором на kinopoisk.ru"}' if $$sql[0];
    
    # жанры
    my @genres;
    if ($$result{'genres'}) {
        foreach my $elem (@{$$result{'genres'}}) {
            # проверяем, есть ли такой идентификатор в оригинальном хэше
            foreach (keys %LIST_GENRES) {
                if ($_ == $elem) {
                    # есть, добавляем его в результирующий массив
                    push @genres, $elem;
                    last;
                }
            }
        }
    }
    
    # страны
    my @countries;
    if ($$result{'countries'}) {
        foreach my $elem (@{$$result{'countries'}}) {
            # проверяем, есть ли такой идентификатор в оригинальном хэше
            foreach (keys %LIST_COUNTRIES) {
                if ($_ == $elem) {
                    # есть, добавляем его в результирующий массив
                    push @countries, $elem;
                    last;
                }
            }
        }
    }

    # остальные поля не требуют уникальности    
    if ($$result{'title'})                     {$title       = tr_html($$result{'title'});}
    if ($$result{'title_orig'})                {$title_orig  = tr_html($$result{'title_orig'});}
    if ($$result{'year'} =~ m/^\d{4}$/)        {$year        = $$result{'year'};}
    if ($$result{'allow_age'} =~ m/^\d{1,2}$/) {$allow_age   = $$result{'allow_age'};}
    if ($$result{'description'})               {$description = tr_html($$result{'description'});}
    if ($$result{'is_serial'})                 {$is_serial   = 1;}
    
    # добавляем
    
    # создаем токен по ключу
    my $obj_token = Mmsite::Lib::Token->new($token);
    return '{"error": "не удалось создать объект токена"}' unless $obj_token;
    
    # объект группы
    my %group_info = (
                         'title'        => $title,
                         'title_orig'   => $title_orig,
                         'description'  => $description,
                         'year'         => $year,
                         'allow_age'    => $allow_age,
                         'owner_id'     => $member_obj->id,
                         'kinopoisk_id' => $kinopoisk,
                         'is_serial'    => $is_serial,
                         'genres'       => \@genres,
                         'countries'    => \@countries
    );
    
    
    my $group = Mmsite::Lib::Groups->create(\%group_info);
    if ($group =~ m/^error/) {
        # ошибка создания
        $obj_token->set( 'error:' . $group, 1 ); # закрываем токен с ошибкой
        $hash{'error'} = $group;
        $json = to_json \%hash;
        on_utf8(\$json);
        return $json;
    }
    
    # создалось, $group->id - идентификатор объекта группы
    # добавляем файлы
    
    # постеры
    my %posters_id;
    
    my $tmp = $$result{'posters'};
    foreach my $file ( keys %{$$result{'posters'}} ) {
    
        # если это uri, то нужно предварительно скачать файл
        if ( _is_uri($file) ) {
            
            # выбираем имя файла для сохранения в пользовательскую директорию
            my $remote_name = '';
            $remote_name = substr( $file, rindex( $file, '/' ) + 1 );
            $remote_name = time() . int( rand(99) ) . '.jpg' if $remote_name !~ /^\w+\.\w+$/;
            
            # скачиваем и сохраняем
            $obj_token->set('скачивание постера с kinopoisk.ru');
            
            my ( $result, $error ) = Mmsite::Lib::Kinopoisk::download_poster( $file, $path_user . $remote_name );
            unless ($result) {
                # ошибка создания
                $obj_token->set( 'error:' . $error, 1 ); # закрываем токен с ошибкой
                $hash{'error'} = $error;
                $json = to_json \%hash;
                on_utf8(\$json);
                return $json;
            }
            
            # скачалось, замещаем
            delete $$tmp{$file};
            $file = $remote_name;
            $$tmp{$file} = '';
        }

        # заполняем хэш
        my %hash = (
                       'type'        => 2,
                       'source_name' => $file,
                       'source_path' => $path_user . $file,
                       'parent_id'   => $group->id,
                       'owner_id'    => $member_obj->id,
                       'title'       => 'poster'
        );

        # создаем объект
        $obj_token->set('добавляем постер');
            
        my $image = Mmsite::Lib::Images->create(\%hash);
        if ($image =~ m/^error/) {
            # ошибка создания
            $obj_token->set( 'error:' . $image, 1 ); # закрываем токен с ошибкой
            $hash{'error'} = $image;
            $json = to_json \%hash;
            on_utf8(\$json);
            return $json;
        }

        # создалось, заносим идентификатор в массив изображений
        $posters_id{$file} = $image->id;
    }
    
    # кадры
    my %shots_id;
    foreach my $file (keys %{$$result{'shots'}}) {
        # заполняем хэш
        my %hash = (
                       type        => 3,
                       source_name => $file,
                       source_path => $path_user . $file,
                       parent_id   => $group->id,
                       owner_id    => $member_obj->id,
                       title       => 'shots'
        );
        # создаем объект
        $obj_token->set('добавляем кадр');

        my $image = Mmsite::Lib::Images->create(\%hash);
        if ($image =~ m/^error/) {
            # ошибка создания
            $obj_token->set( 'error:' . $image, 1 ); # закрываем токен с ошибкой
            $hash{'error'} = $image;
            $json = to_json \%hash;
            on_utf8(\$json);
            return $json;
        }
        
        # создалось, заносим идентификатор в массив изображений
        $shots_id{$file} = $image->id;
    }
    
    # файлы
    my %files_id;
    while ( my ( $file_name, $lnk ) = each %{$$result{'files'}} ) {
        # заполняем хэш
        my %hash = (
                       source_path => $path_user . $file_name,
                       type        => $$lnk{'type'},
                       file_id     => 0, # добавляем файлы без привязки к какому-либо файлу
                       parent_id   => $group->id,
                       title       => $$lnk{'title'},
                       source_name => $file_name,
                       owner_id    => $member_obj->id,
                       translate   => 0,
                       description => ''
        );
        # создаем объект
        $obj_token->set( 'добавляем файл ' . tr_sql($file_name) );

        my $file = Mmsite::Lib::Files->create(\%hash);
        if ($file =~ m/^error/) {
            # ошибка создания
            $obj_token->set( 'error:' . $file, 1 ); # закрываем токен с ошибкой
            $hash{'error'} = $file;
            $json = to_json \%hash;
            on_utf8(\$json);
            return $json;
        }
        
        # создалось, заносим идентификатор в массив файлов
        $files_id{$file_name} = $file->id;
    }
    
    # субтитры
    my %subtitles_id;
    while ( my ( $file_name, $lnk ) = each %{$$result{'subtitles'}} ) {
        # получаем идентификатор родительского файла
        my $parent_id = $$lnk{'parent'};
        $parent_id = $files_id{$parent_id};
        
        # заполняем хэш
        my %hash = (
                       source_path => $path_user . $file_name,
                       type        => 2, # тип для субтитров
                       file_id     => $parent_id, # файл обязательно привязан к какому-либо файлу
                       group_id    => $group->id,
                       title       => $$lnk{'title'},
                       source_name => $file_name,
                       owner_id    => $member_obj->id,
                       translate   => 0,
                       description => ''
        );
        # создаем объект
        $obj_token->set( 'добавляем файл ' . tr_sql($file_name) );

        my $file = Mmsite::Lib::Files->create(\%hash);
        if ($file =~ m/^error/) {
            # ошибка создания
            $obj_token->set( 'error:' . $file, 1 ); # закрываем токен с ошибкой
            $hash{'error'} = $file;
            $json = to_json \%hash;
            on_utf8(\$json);
            return $json;
        }
        
        # создалось, заносим идентификатор в массив файлов
        $subtitles_id{$file_name} = $file->id;
    }
    
    # все создалось, можно удалить исходники
    foreach my $file (keys %{$$result{'posters'}}) {
        unlink($path_user . $file);
    }
    
    foreach my $file (keys %{$$result{'shots'}}) {
        unlink($path_user . $file);
    }
    
    while ( my ( $file_name, $lnk ) = each %{$$result{'files'}} ) {
        unlink($path_user . $file_name);
    }
    
    while ( my ( $file_name, $lnk ) = each %{$$result{'subtitles'}} ) {
        unlink($path_user . $file_name);
    }
    
    # выводим идентификатор созданного объекта группы  
    $obj_token->set( $group->id, 1 );
    $hash{'result'} = $group->id;
    $json = to_json \%hash;
    on_utf8(\$json);
    return $json;
};

# получаем ссылку на массив с именами пользовательских файлов и ссылку на хэшь с присланными данными
# возвращаем истину или ложь (вторым параметром неуникальный или отсутствующий файл)
sub _file_exists_and_uniq_in_user_dir {
    my ( $user_files, $data ) = @_;
    
        foreach my $file_name (keys %$data) {
            my $exists = 0;
            
            # помним, что у нас могут быть не имена файлов, а ссылки
            if ( _is_uri($file_name) ) {$exists = 1;}
            
            # проходимся по всем файлам в пользовательской директории и смотрим, есть ли указанный файл
            unless ($exists) {
                foreach (@$user_files) { 
                    if ($_ eq $file_name) {
                        # файл найден, исключаем его из массива, чтобы сохранить уникальность
                        $exists = 1;
                        $_ = '';
                        last;
                    }
                }
            }
            
            # если файл не нашелся, то выходим с ошибкой
            return( 0, $file_name ) unless $exists;
        }

    return 1;
}

# получаем строку и выдаем истину, если это uri
sub _is_uri {
    my ($str) = @_;
    if ($str =~ m!http[s]*://!) {return 1;} else {return;}
}

1;
