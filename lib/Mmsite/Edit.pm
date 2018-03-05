######################################################################################
# модуль редактирования объекта группы
######################################################################################
package Mmsite::Edit;
use Dancer2 appname => 'Mmsite';
use Modern::Perl;
use utf8;
use Encode;
use Mmsite::Lib::Vars;
use Mmsite::Lib::Auth;
use Mmsite::Lib::Db;
use Mmsite::Lib::Groups;
use Mmsite::Lib::Images;
use Mmsite::Lib::Files;
use Mmsite::Lib::Ffmpeg;

prefix '/edit';

# форма редактирования объекта группы с файлами
get '/:group_id' => sub {
    # авторизация
    my ( $user_id, $user_name, $user_role, $user_sys, $users_sys_id ) = Auth();  
    redirect '/' if $user_role < 2;


    # получаем идентификатор объекта группы
    my $group_id = route_parameters->get('group_id');
    redirect '/' if $group_id !~ m/^\d+$/;
    
    # проверяем на верный идентификатор объекта группы
    my $obj_group = Mmsite::Lib::Groups->new($group_id);
    redirect '/' unless $obj_group;
   
    # получаем информацию об объекте и формируем json структуру
    $obj_group->get();
    
    my $data = {
                   kinopoisk_id => $obj_group->kinopoisk_id,
                   title        => $obj_group->title,
                   title_orig   => $obj_group->title_orig,
                   year         => $obj_group->year,
                   allow_age    => $obj_group->allow_age,
                   is_serial    => $obj_group->is_serial,
                   description  => $obj_group->description,
                   group_id     => $group_id
    };
    
    # добавляем страны и жанры
    my @countries;
    my @genres;
    push @countries, $_ foreach ( @{$obj_group->countries} );
    push @genres,    $_ foreach ( @{$obj_group->genres} );
    $$data{'countries'} = \@countries;
    $$data{'genres'}    = \@genres;

    # добавляем постеры
    my @posters = $obj_group->get_images('posters'); # id, title, url_preview, url, url_orig
    my @posters_json;
    for ( my $i = 0; $i < scalar(@posters); $i = $i + 5) {
        my $tmp = {
                     'id'   => $posters[$i],
                     'name' => $posters[$i+1],
                     'url'  => $posters[$i+4]
        };
        push @posters_json, $tmp;
    }
    $$data{'posters'} = \@posters_json;
    
    # добавляем кадры
    my @shots = $obj_group->get_images('shots'); # id, title, url_preview, url, url_orig
    my @shots_json;
    for ( my $i = 0; $i < scalar(@shots); $i = $i + 5) {
        my $tmp = {
                     'id'   => $shots[$i],
                     'name' => $shots[$i+1],
                     'url'  => $shots[$i+4]
        };
        push @shots_json, $tmp;
    }
    $$data{'shots'} = \@shots_json;
    
    # добавляем файлы с субтитрами files subtitles
    my @files = $obj_group->get_files('all'); # id, type, title, file, size (bytes), translate, dependent (link)
    my @files_json;
    my @subtitles_json;
    for ( my $i = 0; $i < scalar(@files); $i = $i + 7) {
        my $tmp = {
                     'id'        => $files[$i],
                     'file'      => $files[$i+3],
                     'title'     => $files[$i+2],
                     'url'       => $URL_FILES . $files[$i+3],
                     'size'      => $files[$i+4],
                     'translate' => $files[$i+5],
                     'type'      => $files[$i+1]
        };
        push @files_json, $tmp;
        
        # субтитры
        # если есть зависимые файлы
        if (scalar(@{$files[$i+6]})) {
            # проходимся по каждому файлу и собираем информацию о нем
            foreach my $depend_id (@{$files[$i+6]}) {
                my $depend = Mmsite::Lib::Files->new($depend_id);
                if ($depend) {
                    $depend->get();
                    my $depend_data = {
                                          id        => $depend->id,
                                          file      => $depend->file,
                                          title     => $depend->title,
                                          url       => $URL_FILES . $depend->file,
                                          size      => $depend->size,
                                          type      => $depend->type,
                                          parent_id => $files[$i]
                    };
                    push @subtitles_json, $depend_data; 
                }
            }
        }
        
    }
    $$data{'files'}     = \@files_json;
    $$data{'subtitles'} = \@subtitles_json;
    
    # переводим в json
    my $data_json = to_json $data;
    
    # заменяем спец символы, для понимания json в javascript клиента
    $data_json =~ s!\\n!\\\\n!g;
    $data_json =~ s!\\r!\\\\r!g;

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
    for ( my $year = $year_now; $year > 1900; $year-- ) {
        # заполняем
        push @$years, {'id' => $year, 'title' => $year };
    }
    
    
    # выводим
    template 'group_edit' => {
                                     'countries_json'  => $countries_json,
                                     'countries'       => $countries,
                                     'genres_json'     => $genres_json,
                                     'genres'          => $genres,
                                     'translates_json' => $translates_json,
                                     'allow_age_json'  => $allow_age_json,
                                     'allow_ages'      => $allow_ages,
                                     'years'           => $years,
                                     'data_json'       => $data_json,
                                     'id'              => $group_id
                               };
};

# добавляем новый объект группы
post '' => sub {
    # авторизация
    my ( $user_id, $user_name, $user_role, $user_sys, $users_sys_id ) = Auth(); 
    return '{"error": "access denied"}' if $user_role < 2;

    my $json = body_parameters->get('json');
    return '{"error":"empty request"}' unless $json;
    
    # ВАРИАНТЫ:
    # полное удаление объекта группы с удалением всех привязанных файлов и информации
    # изменение общей информации, включая страны и жанры (массив)
    # добавление / удаление файлов (постеров, кадров, файлов, субтитров)
    
    # разбираем данные
    $json = Encode::encode_utf8($json);
    my $result;
    unless ( eval { $result = from_json $json } ) {
        return '{"error":"ожидаются данные в json формате"}';
    }
    
    # получаем идентификатор объекта группы
    return '{"error":"не указан идентификатор группы"}' unless $$result{'group_id'};
    
    my $obj_group = Mmsite::Lib::Groups->new( $$result{'group_id'} );
    return '{"error":"указан неверный идентификатор группы"}' unless $obj_group;
    
    # данные получены в json, проверяем на требования и сохраняем
    # проходимся поочередно по всем
    
    # идентификатор на kinopoisk.ru
    if ( exists $$result{'kinopoisk_id'} ) {
        # проверяем
        return '{"error":"идентификатор на kinopoisk.ru должен содержать только цифры"}' if $$result{'kinopoisk_id'} !~ m/^\d+$/;
    
        my $sql = sql("SELECT id FROM groups_data WHERE kinopoisk_id='$$result{'kinopoisk_id'}' AND id != '$$result{'group_id'}';");
        return '{"error":"на сервере уже существует файл с таким идентификатором на kinopoisk.ru"}' if $$sql[0];
        
        # сохраняем
        return '{"error":"не удалось"}' unless ( $obj_group->set( 'kinopoisk_id', $$result{'kinopoisk_id'} ) );
    }
    
    # название
    if ( exists $$result{'title'} ) {
        # сохраняем
        return '{"error":"не удалось"}'unless ( $obj_group->set( 'title', $$result{'title'} ) );
    }
    
    # оригинальное название
    if ( exists $$result{'title_orig'} ) {
        # сохраняем
        return '{"error":"не удалось"}' unless ( $obj_group->set( 'title_orig', $$result{'title_orig'} ) );
    }
    
    # год
    if ( exists $$result{'year'} ) {
        # проверяем
        if ($$result{'year'} !~ m/^\d{4}$/) {$$result{'year'} = 0;}
    
        # сохраняем
        return '{"error":"не удалось"}'unless ( $obj_group->set( 'year', $$result{'year'} ) );
    }
    
    # разрешенный возраст просмотра
    if ( exists $$result{'allow_age'} ) {
        # проверяем
        if ($$result{'allow_age'} !~ m/^[-]*\d{1,2}$/) {$$result{'allow_age'} = 0;}
    
        # сохраняем
        return '{"error":"не удалось"}' unless ( $obj_group->set( 'allow_age', $$result{'allow_age'} ) );
    }
    
    # описание
    if ( exists $$result{'description'} ) {
        # сохраняем
        return '{"error":"не удалось"}' unless ( $obj_group->set( 'description', $$result{'description'} ) );
    }
    
    # многосерийность
    if ( exists $$result{'is_serial'} ) {
        # сохраняем
        return '{"error":"не удалось"}' unless ( $obj_group->set( 'is_serial', $$result{'is_serial'} ) );
    }
    
    # жанры
    if ( exists $$result{'genres'} ) {
        # формируем новый массив из проверенных элементов
        my @tmp;
        
        foreach (@{$$result{'genres'}}) {
            if ($LIST_GENRES{$_}) { push @tmp, $_; }
        }

        # сохраняем
        return '{"error":"не удалось"}' unless ( $obj_group->set( 'genres', \@tmp ) );
    }
    
    # страны
    if ( exists $$result{'countries'} ) {
        # формируем новый массив из проверенных элементов
        my @tmp;
        
        foreach (@{$$result{'countries'}}) {
            if ($LIST_COUNTRIES{$_}) { push @tmp, $_; }
        }

        # сохраняем
        return '{"error":"не удалось"}' unless ( $obj_group->set( 'countries', \@tmp ) );
    }
    
    # модификация файлов
    if ( exists $$result{'file_command'} ) {
        
        if ($$result{'file_command'} eq 'delete') {
            # запрос на удаление
            
            # проверяем на идентификатор файла
            return '{"error":"не указан идентификатор файла"}' unless $$result{'file_id'};
            
            my $error = 0;
            
            if ( $$result{'file_type'} eq 'posters' ) {
                # постер
                $error = 1 unless ( $obj_group->delete_poster( $$result{'file_id'} ) );
            }
            elsif ( $$result{'file_type'} eq 'shots' ) {
                # кадр
                $error = 1 unless ( $obj_group->delete_shot( $$result{'file_id'} ) );
            }
            else {
                # файл
                $error = 1 unless ( $obj_group->delete_file( $$result{'file_id'} ) );
            }
            
            return '{"error":"не удалось"}' if $error;

        }
        elsif ($$result{'file_command'} eq 'create') {
            # запрос на добавление файлов к объекту группы
            my %answer;
            
            # получаем ключ токена, т.к. это длительная операция
            my $token = body_parameters->get('token');
            return '{"error": "empty token"}' unless $token;
            
            # создаем токен по ключу
            my $obj_token = Mmsite::Lib::Token->new($token);
            return '{"error": "не удалось создать объект токена"}' unless $obj_token;
            
            # получаем список файлов в пользовательской директории
            my $path_user = $PATH_USERS . '/' . $user_id . '/';
            opendir my ($tempdir), $path_user;
            my @file = readdir $tempdir;
            closedir $tempdir;  
            @file = grep !/^\.\.?$/, @file;
           
            # проходимся по всем присланным элементам и добавляем
            my $flag_change_listing = 0;
            foreach my $obj (@{$$result{'create_data'}}) {
            
                # проверяем есть ли файл
                my $is = 0;
                foreach (@file) {
                    if ($_ eq $$obj{'file'}) {
                        $is = 1;
                        $_ = '';
                        last;
                    }
                }
                if ($is) {
                    # файл нашелся, можно добавлять
                    
                    # заполняем хэш
                    my %hash = (
                                  source_name => $$obj{'file'},
                                  source_path => $path_user . $$obj{'file'},
                                  parent_id   => $obj_group->id,
                                  owner_id    => $user_id
                   );
                   
                   if ($$obj{'type'} eq 'posters') {
                       $hash{'type'}  = 2;
                       $hash{'title'} = 'poster';
                   }
                   elsif ($$obj{'type'} eq 'shots') {
                       $hash{'type'}  = 3;
                       $hash{'title'} = 'shots';
                   }
                   else {
                       
                       if ( Mmsite::Lib::Ffmpeg::is_subtitle_extension($$obj{'file'}) ) {
                           $hash{'type'} = 2, # тип для субтитров
                       }
                       else {
                           $hash{'type'} = 0, # тип для файлов по умолчанию
                           $flag_change_listing = 1; # флаг смены позиции в листинге на индексной странице
                       }
                       $hash{'file_id'}     = $$obj{'parent_id'} || 0, # файл привязан к какому-либо файлу
                       $hash{'group_id'}    = $obj_group->id,
                       $hash{'title'}       = $$obj{'file'},
                       $hash{'translate'}   = 0,
                       $hash{'description'} = ''
                   }
                   
                   # хэшь заполнили, можно создавать
                   my $file;
                   
                   if ( $$obj{'type'} eq 'posters' || $$obj{'type'} eq 'shots' ) {
                       $obj_token->set('добавляем файлы изображений');
                       $file = Mmsite::Lib::Images->create(\%hash);
                   }
                   else {
                       $obj_token->set("добавляем файл $hash{'source_name'}");
                       $file = Mmsite::Lib::Files->create(\%hash);
                   }
                   
                   if ($file !~ m/^error/) {
                       # создалось
                       
                       # удаляем исходник
                       unlink( $path_user . $$obj{'file'} );
                       
                       # заполняем структуру с данными для вывода
                       $file->get();
                       
                       my %file_hash;
                       
                       if ($$obj{'type'} eq 'posters') {
                           $file_hash{'id'}   = $file->id;
                           $file_hash{'name'} = $file->title;
                           $file_hash{'url'}  = $file->url_orig;
                           push @{$answer{'posters'}}, \%file_hash;
                       }
                       elsif ($$obj{'type'} eq 'shots') {
                           $file_hash{'id'}   = $file->id;
                           $file_hash{'name'} = $file->title;
                           $file_hash{'url'}  = $file->url_orig;
                           push @{$answer{'shots'}}, \%file_hash;
                       }
                       else {
                           $file_hash{'id'}        = $file->id;
                           $file_hash{'file'}      = $file->file;
                           $file_hash{'title'}     = $file->title;
                           $file_hash{'url'}       = $URL_FILES . $file->file;
                           $file_hash{'size'}      = $file->size;
                           $file_hash{'translate'} = $file->translate;
                           $file_hash{'type'}      = $file->type;
                           $file_hash{'parent_id'} = $file->file_id;

                           unless ( $file->type ) {
                               push @{$answer{'files'}}, \%file_hash;
                           }
                           else {
                               push @{$answer{'depends'}}, \%file_hash;
                           }
                       }
                       
                       # чистим кеш файла
                       $file->clear_cache_data();
                   }
                   else {
                       $obj_token->set( 'error:' . $file, 1 ); # закрываем токен с ошибкой
                   }
                }
            }
            
            # очищаем кеш
            $obj_group->clear_cache_data_image();
            $obj_group->clear_cache_data_file();
            
            # перемещаем позицию в листинге на главной, если нужно
            if ($flag_change_listing) {
                $obj_group->add_in_listing();
            }
            
            # указываем в токене, что все выполнено успешно
            $obj_token->set( $obj_group->id, 1 );
            
            # переводим структуру в JSON и отдаем
            my $data_json = to_json \%answer;
            return $data_json;
        }
        elsif ($$result{'file_command'} eq 'edit') {
            # запрос на изменение свойств файла
            
            # проверяем на идентификатор файла
            return '{"error":"не указан идентификатор файла"}' unless $$result{'file_id'};
            
            my $obj_file = Mmsite::Lib::Files->new($$result{'file_id'});
            return '{"error":"указан неверный идентификатор файла"}' unless $obj_file;
            
            return '{"error":"указан неверный параметр задачи"}' if $$result{'file_action'} !~ m/^(title|type|translate)$/;
            
            # меняем
            return '{"error":"не удалось"}' unless ( $obj_file->set( $$result{'file_action'}, $$result{'file_value'} ) );
            
            # очищаем кеш
            $obj_group->clear_cache_data_file();
        }
        elsif ($$result{'file_command'} eq 'delete_group') {
            # удаление объекта группы
            
            # удаляем файлы
            my ($result, $error) = $obj_group->delete();
            return '{"error":"не удалось: ' . $error . '"}' unless $result;
        }
    }
    
    return '{"result":"1"}';
};

1;
