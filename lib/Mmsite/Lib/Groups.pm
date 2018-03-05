################################################################################
#  Управление разделами
################################################################################
package Mmsite::Lib::Groups;

#  new => объявляет объект группы
#  create => создает объект группы и возвращает указатель на него
#  get => получение общей информации об объекте
#  set => изменение общей информации об обекте
#  get_images => возвращаем массив с привязанными к объекту изображениями
#  get_files => возвращаем массив с привязанными к объекту файлами
#  preview => возвращаем сформированный HTML превьюшки
#  delete_poster => функция инициализации удаления постера
#  delete_shot => функция инициализации удаления кадра
#  delete_file => функция инициализации удаления файла
#  delete => функция удаления объекта группы
#  link_people => функция создает привязку человека к объекту
#  unlink_people => функция удаляет привязку человека к объекту
#  add_in_listing => функция добавления в листинг на индексной странице анонса объекта группы
#  delete_in_listing => функция удаления из листинга на индексной странице анонса объекта группы
#  clear_cache_data => сброс кеша с данными об объекте
#  clear_cache_data_image => сброс кеша с данными об изображениях объекта
#  clear_cache_data_file => сброс кеша с данными об файлах объекта
#  clear_cache_data_preview => сброс кеша с данными готовой превьюшки объекта

################################################################################
# настройки
################################################################################
my $SUF_PREVIEW = 'group_preview_'; # суффикс ключа memcached для превью
my $SUF_DATA    = 'group_data_';    # суффикс ключа memcached для хранения данных из базы
my $SUF_IMAGE   = 'group_image_';   # суффикс ключа memcached для хранения данных об изображениях
my $SUF_FILE    = 'group_file_';    # суффикс ключа memcached для хранения данных о файлах
################################################################################

use Modern::Perl;
use utf8;
use JSON::XS;
use Data::Structure::Util qw( unbless );
use Mmsite::Lib::Vars;
use Mmsite::Lib::Db;
use Mmsite::Lib::Mem;
use Mmsite::Lib::Images;
use Mmsite::Lib::Files;
use Mmsite::Lib::Template;

# инициализируем объект json
my $json_xs = JSON::XS->new();
$json_xs->utf8();

# инициализируем хэш для хранения созданных объектов
my %OBJECT;

sub new {
    my ( $class, $group_id ) = @_;
    
    # не указали идентификатор группы
    return unless defined $group_id;
    
    # если объект уже создан, то отдаем
    return $OBJECT{$group_id} if $OBJECT{$group_id};

    # проверка на допустимый идентификатор
    return unless _check_group_id($group_id);
    
    # создаем объект
    my $self = { id => $group_id };
    $OBJECT{$group_id} = bless $self, $class;
    return( $OBJECT{$group_id} );
}

# метод создания объекта группы
# возвращает объект
sub create {
    my ( $class, $self ) = @_;
    
    # пытаемся создать объект и если успешно, то возвращаем объект, а если нет, то строку с ошибкой
    
    # проверки
    return 'error: title is empty'                         if $$self{'title'} eq '';
    return 'error: title should be less 100 symbols'       if (length($$self{'title'}) > 100);
    return 'error: title_orig should be less 100 symbols'  if ( length($$self{'title_orig'}) > 100);
    return 'error: description should be less 800 symbols' if ( length($$self{'description'}) > 800);

    $$self{'year'}      = 0  if $$self{'year'}      !~ m/^\d{4}$/;
    $$self{'allow_age'} = 0  if $$self{'allow_age'} !~ m/^\d{1,2}$/;
    $$self{'owner_id'}  = -1 if $$self{'owner_id'}  !~ m/^\d+$/;
    
    return 'error: kinopoisk_id must be only numeric symbols' if $$self{'kinopoisk_id'} !~ m/^\d+$/;
    
    $$self{'is_serial'} ? $$self{'is_serial'} = 'true' : $$self{'is_serial'} = 'false';
    
    # создаем объект
    $$self{'title'}       = tr_html($$self{'title'});       $$self{'title'}       = tr_sql($$self{'title'});
    $$self{'title_orig'}  = tr_html($$self{'title_orig'});  $$self{'title_orig'}  = tr_sql($$self{'title_orig'});
    $$self{'description'} = tr_html($$self{'description'}); $$self{'description'} = tr_sql($$self{'description'});

    my $sql = sql("INSERT INTO groups_data (title,title_orig,description,year,allow_age,owner_id,kinopoisk_id,is_serial) VALUES ('$$self{'title'}','$$self{'title_orig'}','$$self{'description'}','$$self{'year'}','$$self{'allow_age'}','$$self{'owner_id'}','$$self{'kinopoisk_id'}',$$self{'is_serial'}) RETURNING id;");    
    return 'error: sql error' unless $$sql[0];
    
    # удалось добавить информацию в базу и получить идентификатор
    $$self{'id'} = $$sql[0];
    
    # указываем жанры и страны
    foreach ( @{$$self{'genres'}} ) {
        next unless m/^\d+$/;
        sql( "INSERT INTO groups_genres (group_id,genres_id) VALUES ('$$self{'id'}','$_');", 1 );
    }
    
    foreach ( @{$$self{'countries'}} ) {
        next unless m/^\d+$/;
        sql( "INSERT INTO groups_countries (group_id,countries_id) VALUES ('$$self{'id'}','$_');", 1 );
    }
    
    # люди
    foreach ( @{$$self{'directors'}} ) {
        next unless m/^\d+$/;
        sql( "INSERT INTO groups_peoples (group_id,peoples_id,is_director) VALUES ('$$self{'id'}','$_',TRUE);", 1 );
    }
    foreach ( @{$$self{'actors'}} ) {
        next unless m/^\d+$/;
        sql( "INSERT INTO groups_peoples (group_id,peoples_id,is_director) VALUES ('$$self{'id'}','$_',FALSE);", 1 );
    }
    
    # теперь проходимся по переданным идентификаторам зависимых файлов и привязываем
    # изображения
    foreach ( @{$$self{'images'}} ) {
        next unless m/^\d+$/;
        my $img = Mmsite::Lib::Images->new($_);
        if ($img) {
           unless ( $img->set( 'owner_id', $$self{'id'} ) ) {
               # не удалось применить
           }
        }
    }
    
    # файлы
    foreach my $fid ( @{$$self{'files'}} ) {
        next unless $fid !~ m/^\d+$/;
        my $file = Mmsite::Lib::Files->new($fid);
        if ($file) {
            unless ( $file->set( 'group_id', $$self{'id'} ) ) {
                # не удалось применить
            }
           
            # если есть зависимые файлы, то также нужно изменить
            foreach ( @{ $file->dependent } ) {
                my $file_dep = Mmsite::Lib::Files->new($_);
                if ($file_dep) {
                    unless ( $file_dep->set( 'group_id', $$self{'id'} ) ) {
                        # не удалось применить
                    }
                }
            }
           
        }
    }
    
    # создаем объект
    $OBJECT{ $$self{'id'} } = bless $self, $class;
    
    # добавляем объект в очередь листинга для вывода на главной
    $OBJECT{ $$self{'id'} }->add_in_listing();
    
    # отдаем
    return $OBJECT{ $$self{'id'} };
}



# получаем свойства объекта группы, возвращаем истину или ложь
sub get {
    my ($self) = @_;
    
    # пытаемся взять данные из кеша
    my $json_decode;
    my $key = $SUF_DATA . $self->{'id'};
    my $memcached = mem_get()->get($key);
    if ($memcached) {
        # данные есть, распарсиваем
        on_utf8(\$memcached);
        if (eval { $json_decode = $json_xs->decode($memcached); }) {
            # удалось распарсить, заносим данные в свойства объекта
            while ( my( $key, $val ) = each(%$json_decode) ) {
                $self->{$key} = $val;
            }
            
            return 1;
        }
    }
    
    # берем данные из базы
    my $sql = sql("SELECT id,title,title_orig,description,year,allow_age,rate_count,rate_val,rate_our,owner_id,kinopoisk_id,is_serial FROM groups_data WHERE id = '$self->{'id'}';");
    return unless $$sql[0];
    
    # данные есть, заносим данные в промежуточный хэш для json, т.к. он не умеет работать с bless свойствами
    my %hash;
    $hash{'id'}           = $$sql[0];
    $hash{'title'}        = $$sql[1];
    $hash{'title_orig'}   = $$sql[2];
    $hash{'description'}  = $$sql[3];
    $hash{'year'}         = $$sql[4];
    $hash{'allow_age'}    = $$sql[5];
    $hash{'rate_count'}   = $$sql[6];
    $hash{'rate_val'}     = $$sql[7];
    $hash{'rate_our'}     = $$sql[8];
    $hash{'owner_id'}     = $$sql[9];
    $hash{'kinopoisk_id'} = $$sql[10];
    $hash{'is_serial'}    = $$sql[11];
    
    # жанры
    $hash{'genres'} = sql("SELECT genres_id FROM groups_genres WHERE group_id='$self->{'id'}' ORDER BY genres_id");
    
    # страны
    $hash{'countries'} = sql("SELECT countries_id FROM groups_countries WHERE group_id='$self->{'id'}' ORDER BY countries_id");
    
    # люди
    $hash{'directors'} = sql("SELECT peoples_id FROM groups_peoples WHERE group_id='$self->{'id'}' AND is_director=TRUE ORDER BY peoples_id");
    $hash{'actors'}    = sql("SELECT peoples_id FROM groups_peoples WHERE group_id='$self->{'id'}' AND is_director=FALSE ORDER BY peoples_id");
    
    # данные есть, заносим данные в свойства объекта
    while ( my( $key, $val ) = each(%hash) ) {
        $self->{$key} = $val;
    }

    # заносим данные в хэш
    $memcached = $json_xs->encode(\%hash);
    mem_get()->delete($key);
    mem_get()->add( $key, $memcached );

    return 1;    
}

# устанавливаем свойства объекта группы, возвращаем истину или ложь
sub set {
    my ( $self, $param, $value ) = @_;
    
    return if $param !~ m/(title|title_orig|description|year|allow_age|rate_count|rate_val|rate_our|owner_id|kinopoisk_id|is_serial|genres|countries)/;
    
    my $error = 0;
    
    if ($param =~ /(genres|countries)/) {
        # данные в привязанных таблицах, в value у нас ссылка на массив с проверенными идентификаторами
        # очищаем
        if ( sql( "DELETE FROM groups_" . "$param WHERE group_id = '$self->{'id'}';", 1 ) ) {
            # добавляем по одному элементу
            foreach (@$value) {
                unless ( sql( "INSERT INTO groups_$param (group_id, $param" . "_id) VALUES ($self->{'id'}, $_);", 1 ) ) {
                    $error = 1;
                    last;
                }
            }
        }
    }
    else {
        # данные в одной таблице
        
        # готовим значение под sql
        if ($param eq 'is_serial') {
            if ($value) {$value = 'TRUE';} else {$value = 'FALSE';}
        }
        else {
            $value = tr_html($value);
            $value = tr_sql($value);
            $value = "'" . $value . "'";
        }
    
        # пробуем установить
        unless ( sql( "UPDATE groups_data SET \"$param\" = $value WHERE id = '$self->{'id'}';", 1 ) ) {$error = 1;}
    }
    
    unless ($error) {
        # установить удалось
        $self->{$param} = $value;
        
        # чистим кеш
        $self->clear_cache_data();
        $self->clear_cache_data_preview();
            
        return 1; 
    }

    # не удалось установить
    return;
}




# получаем данные по изображениям объекта группы и производим выборку по $act (poster|posters|shots), возвращаем массив [id,title,url_preview,url,url_orig]
sub get_images {
    my ( $self, $act ) = @_;

    # пытаемся взять данные из кеша
    my @result;
    my $mass_decode;
    my $key = $SUF_IMAGE . $self->{'id'};
    my $memcached = mem_get()->get($key);
    if ($memcached) {
        # данные есть, распарсиваем
        on_utf8(\$memcached);
        eval { $mass_decode = $json_xs->decode($memcached); }
    }
    
    # если данные из кеша извлечь не удалось, то берем из базы
    if (!$mass_decode) {
        # берем данные из базы, тип у нас может быть 2|3
        my $sql = sql("SELECT id,type FROM images WHERE parent_id = '$self->{'id'}' AND type < 4;");
        return unless $$sql[0];
        
        my @temp;
        for ( my $i = 0; $i < @$sql; $i += 2 ) {
        
            # приводим к верному типу для Mmsite::Lib::Images
            if ($$sql[$i+1] == 1)    {$$sql[$i+1] = 2;}
            elsif ($$sql[$i+1] == 4) {$$sql[$i+1] = 5;}
            
            # запрашиваем информацию и собираем массив
            my $img = Mmsite::Lib::Images->new( $$sql[$i], $$sql[$i+1] );
            if ($img) {
                $img->get();
                push @temp, $img->id       ; # id
                push @temp, $img->type     ; # type
                push @temp, $img->title    ; # title
                push @temp, $img->url_mini ; # url_preview
                push @temp, $img->url_std  ; # url
                push @temp, $img->url_orig ; # url_orig
            }

        }
        
        # устанавливаем верный указатель для дальнейшей обработки
        $mass_decode = \@temp;
    }
    
    # данные есть
    for ( my $i = 0; $i < @$mass_decode; $i += 6 ) { # [ id, type, title, url_mini, url, url_big ]
    
        if ( $act eq 'poster' && $$mass_decode[$i+1] == 2) {
            # запрос основного постера, добавляем в массив
            push @result, $$mass_decode[$i]   ; # id
            push @result, $$mass_decode[$i+2] ; # title
            push @result, $$mass_decode[$i+3] ; # url_preview
            push @result, $$mass_decode[$i+4] ; # url
            push @result, $$mass_decode[$i+5] ; # url_orig

            # т.к. основной постер только один, прекращаем выборку
            return(@result);
        }
        elsif ( $act eq 'posters' && $$mass_decode[$i+1] == 2 ) {
            # запрос постеров, добавляем в массив
            push @result, $$mass_decode[$i]   ; # id
            push @result, $$mass_decode[$i+2] ; # title
            push @result, $$mass_decode[$i+3] ; # url_preview
            push @result, $$mass_decode[$i+4] ; # url
            push @result, $$mass_decode[$i+5] ; # url_orig
        }
        elsif ( $act eq 'shots' && $$mass_decode[$i+1] == 3 ) {
            # запрос кадров, добавляем в массив
            push @result, $$mass_decode[$i]   ; # id
            push @result, $$mass_decode[$i+2] ; # title
            push @result, $$mass_decode[$i+3] ; # url_preview
            push @result, $$mass_decode[$i+4] ; # url
            push @result, $$mass_decode[$i+5] ; # url_orig
        }

    }

    # заносим данные в хэш
    $memcached = $json_xs->encode($mass_decode);
    mem_get()->delete($key);
    mem_get()->add( $key, $memcached );

    # возвращаем данные
    return(@result);  
}


# получаем данные по файлам объекта группы и производим выборку по $act (trailers|view|all), возвращаем массив
sub get_files {
    my ( $self, $act ) = @_;

    # пытаемся взять данные из кеша
    my @result;
    my $mass_decode;
    my $key = $SUF_FILE . $self->{'id'};
    my $memcached = mem_get()->get($key);
    if ($memcached) {
        # данные есть, распарсиваем
        on_utf8(\$memcached);
        eval { $mass_decode = $json_xs->decode($memcached); }
    }
    
    # если данные из кеша извлечь не удалось, то берем из базы
    if (!$mass_decode) {
        # берем данные из базы, file_id = 0, т.к. выбираем только не родительские файлы
        my $sql = sql("SELECT id,type FROM files WHERE parent_id = '$self->{'id'}' AND file_id = 0 ORDER BY title;");
        return unless $$sql[0];
        
        my @temp;
        for ( my $i = 0; $i < @$sql; $i += 2 ) {
        
            # запрашиваем информацию и собираем массив
            my $file = Mmsite::Lib::Files->new($$sql[$i]);
            if ($file) {
                $file->get();
                push @temp, $file->id;
                push @temp, $file->type;
                push @temp, $file->title;
                push @temp, $file->file;
                push @temp, $file->size;
                push @temp, $file->res_x;
                push @temp, $file->res_y;
                push @temp, $file->is_web;
                push @temp, $file->count_download;
                push @temp, $file->count_view;
                push @temp, $file->translate;
                push @temp, $file->description;
                push @temp, $file->other;
                push @temp, $file->duration;
                push @temp, $file->dependent;
            }

        }
        
        # устанавливаем верный указатель для дальнейшей обработки
        $mass_decode = \@temp;
    }
    
    # данные есть
    for ( my $i = 0; $i < @$mass_decode; $i += 15 ) { # [ id, type, title, file, size, res_x, res_y, is_web, count_download, count_view, translate, description, other, duration, dependent ]
    
        if ( $act eq 'trailers' && $$mass_decode[$i+1] == 1 && $$mass_decode[$i+7] ) {
            # запрос трейлеров, добавляем в массив
            push @result, $$mass_decode[$i];   # id
            push @result, $$mass_decode[$i+2]; # title
            push @result, $$mass_decode[$i+3]; # file
            push @result, $$mass_decode[$i+4]; # size
            push @result, $$mass_decode[$i+5]; # res_x
            push @result, $$mass_decode[$i+6]; # res_y
        }
        elsif ( $act eq 'view' && $$mass_decode[$i+1] == 0 ) {
            # запрос файлов для скачивания, добавляем в массив
            push @result, $$mass_decode[$i];    # id
            push @result, $$mass_decode[$i+2];  # title
            push @result, $$mass_decode[$i+3];  # file
            push @result, $$mass_decode[$i+4];  # size
            push @result, $$mass_decode[$i+5];  # res_x
            push @result, $$mass_decode[$i+6];  # res_y
            push @result, $$mass_decode[$i+7];  # is_web
            push @result, $$mass_decode[$i+8];  # count_download
            push @result, $$mass_decode[$i+9];  # count_view
            push @result, $$mass_decode[$i+10]; # translate
            push @result, $$mass_decode[$i+11]; # description
            push @result, $$mass_decode[$i+13]; # duration
            push @result, $$mass_decode[$i+14]; # dependent
        }
        elsif ( $act eq 'all' ) {
            # запрос всех файлов (используется для редактирования)
            push @result, $$mass_decode[$i];    # id
            push @result, $$mass_decode[$i+1];  # type
            push @result, $$mass_decode[$i+2];  # title
            push @result, $$mass_decode[$i+3];  # file
            push @result, $$mass_decode[$i+4];  # size
            push @result, $$mass_decode[$i+10]; # translate
            push @result, $$mass_decode[$i+14]; # dependent
        }

    }

    # заносим данные в хэш
    $memcached = $json_xs->encode($mass_decode);
    mem_get()->delete($key);
    mem_get()->add( $key, $memcached );

    # возвращаем данные
    return(@result);  
}



# метод вывода превью для объекта группы
sub preview {
    my ( $self ) = @_;
    
    # пробуем взять из кеша
    my $key = $SUF_PREVIEW . $self->{'id'};
    my $memcached = mem_get()->get($key);
    if ($memcached) {
        # данные есть, отдаем
        on_utf8(\$memcached);
        return $memcached;
    }
    
    # получаем информацию по объекту
    $self->get();
    my $poster_url   = $URL_POSTERS_DEF_MINI;
    my $poster_title = $self->{'title'};
    my @poster = $self->get_images('poster');
    # если есть постер, то используем его
    if ($poster[0]) {
        $poster_url   = $poster[2];
        $poster_title = $poster[1];
    }
    
    # генерируем html превью
    $memcached = template_get('group_preview');
    
    # идентификатор, название, год, жанры, страны, последний добавленный файл
    $memcached =~ s/%ID%/$self->{'id'}/gims;
    $memcached =~ s/%NAME%/$self->{'title'}/gims;
    $memcached =~ s/%POSTER_URL%/$poster_url/gims;
    $memcached =~ s/%POSTER_TITLE%/$poster_title/gims;
    if (!$self->{'year'}) {$memcached =~ s/<!--\*[\s]*year[\s]*-->.+?<!--\*[\s]*\/year[\s]*-->//;} else {$memcached =~ s/%YEAR%/$self->{'year'}/gims;}
    if (!$self->{'is_serial'}) {$memcached =~ s/<!--\*[\s]*serial[\s]*-->.+?<!--\*[\s]*\/serial[\s]*-->//;}
    
    # жанры и страны
    my $text = '';
    if ( scalar( @{$self->{'genres'}} ) == 0 ) {$memcached =~ s/<!--\*[\s]*genres[\s]*-->.+?<!--\*[\s]*\/genres[\s]*-->//;}
    else {
        $text = join ", ", map {$LIST_GENRES{$_}} @{$self->{'genres'}};
        $text =~ s/,\s$//;
        $memcached =~ s/%GENRES%/$text/gims;
    }
    $text = '';
    if ( scalar( @{$self->{'countries'}} ) == 0 ) {$memcached =~ s/<!--\*[\s]*countries[\s]*-->.+?<!--\*[\s]*\/countries[\s]*-->//;}
    else {
        $text = join ", ", map {$LIST_COUNTRIES{$_}} @{$self->{'countries'}};
        $text =~ s/,\s$//;
        $memcached =~ s/%COUNTRIES%/$text/gims;
    }
    
    # сохраняем в кеш
    mem_get()->delete($key);
    mem_get()->add( $key, $memcached );
    
    return $memcached;
}


# метод удаления постера, возвращает булево
sub delete_poster {
    my ( $self, $image_id ) = @_;
    # пытаемся удалить
    my $img = Mmsite::Lib::Images->new( $image_id, 2 );
    if ($img) {
        if ( $img->delete() ) {
            # удалилось, чистим кеш
            $self->clear_cache_data_image();
            $self->clear_cache_data_preview();
            return 1;
        }
    }
    return;
}

# метод удаления кадра, возвращает булево
sub delete_shot {
    my ( $self, $image_id ) = @_;
    # пытаемся удалить
    my $img = Mmsite::Lib::Images->new( $image_id, 3 );
    if ($img) {
        if ( $img->delete() ) {
            # удалилось, чистим кеш
            $self->clear_cache_data_image();
            return 1;
        }
    }
    return;
}

# метод удаления файла, возвращает булево
sub delete_file {
    my ( $self, $file_id ) = @_;
    # пытаемся удалить
    my $file = Mmsite::Lib::Files->new($file_id);
    if ($file) {
        # у файла могут быть привязанные файлы, получаем их
        $file->get();
        
        foreach ( @{ $file->dependent } ) {
            # удаляем привязанные
            my $file_dep = Mmsite::Lib::Files->new($_);
            if ($file_dep) {
                unless ( $file_dep->delete() ) {
                    # удалить не удалось, чистим кеш и выходим
                    $self->clear_cache_data_file();
                    return();
                }
            }
            
        }

        # теперь можно удалить этот файл
        if ( $file->delete() ) {
            # удалилось, чистим кеш
            $self->clear_cache_data_file();
            return 1;
        }
    }
    return;
}

# метод удаления объекта группы
sub delete {
    my ( $self ) = @_;

    # удаляем файлы
    my @files = $self->get_files('all'); # id, type, title, file, size (bytes), translate, dependent (link)
    for my $i ( 0 .. @files ) {
    
        my $obj_file = Mmsite::Lib::Files->new($files[$i]);
        unless ($obj_file) {
            $self->clear_cache_data_file(); # чистим кеш
            return( 0, 'не удалось обратиться к привязанному файлу' );
        }
                
        unless ( $obj_file->delete() ) {
            $self->clear_cache_data_file(); # чистим кеш
            return( 0, 'не все файлы были удалены' );
        }
        
        $i += 7;
    }
            
    # удаляем изображения
    my @posters = $self->get_images('posters'); # id, title, url_preview, url, url_orig
    my @shots   = $self->get_images('shots'); # id, title, url_preview, url, url_orig
    my @images  = (@posters, @shots);
    for my $i ( 0 .. @images ) {
    
        my $obj_image = Mmsite::Lib::Images->new($images[$i]);
        unless ($obj_image) {
            $self->clear_cache_data_image(); # чистим кеш
            $self->clear_cache_data_preview(); # чистим кеш
            return( 0, 'не удалось обратиться к привязанному изображению' );
        }
                
        unless ( $obj_image->delete() ) {
            $self->clear_cache_data_image(); # чистим кеш
            $self->clear_cache_data_preview(); # чистим кеш
            return( 0, 'не все изображения были удалены' );
        }
        
        $i += 5
    }
            
    # удаляем информацию об объекте группы
    unless ( sql( "DELETE FROM groups_peoples WHERE group_id = '$self->{'id'}';", 1 ) ) {
        $self->clear_cache_data(); # чистим кеш
        $self->clear_cache_data_preview(); # чистим кеш
        return( 0, 'ошибка базы данных' );
    }
    
    unless ( sql( "DELETE FROM groups_genres WHERE group_id = '$self->{'id'}';", 1 ) ) {
        $self->clear_cache_data(); # чистим кеш
        $self->clear_cache_data_preview(); # чистим кеш
        return( 0, 'ошибка базы данных' );
    }
    
    unless ( sql( "DELETE FROM groups_countries WHERE group_id = '$self->{'id'}';", 1 ) ) {
        $self->clear_cache_data(); # чистим кеш
        $self->clear_cache_data_preview(); # чистим кеш
        return( 0, 'ошибка базы данных' );
    }
    
    unless ( sql( "DELETE FROM groups_list WHERE group_id = '$self->{'id'}';", 1 ) ) {
        return( 0, 'ошибка базы данных' );
    }

    unless ( sql( "DELETE FROM groups_data WHERE id = '$self->{'id'}';", 1 ) ) {
        $self->clear_cache_data(); # чистим кеш
        $self->clear_cache_data_preview(); # чистим кеш
        return( 0, 'ошибка базы данных' );
    }
    
    # очищаем кеши
    $self->clear_cache_data_preview();
    $self->clear_cache_data();
    $self->clear_cache_data_image();
    $self->clear_cache_data_file();
    
    # удаляем объект и данные
    my $id = $self->{'id'};
    unbless $self;
    %$self = ();
    $OBJECT{$id} = 0;
        
    return 1;
}

# метод добавления в листинг на индексной странице анонса объекта группы
sub add_in_listing {
    my ( $self ) = @_;
    
    # удаляем из личтинга, если есть
    return unless $self->delete_in_listing();
    
    # добавляем на первую позицию
    if ( sql("INSERT INTO groups_list (group_id) VALUES ('$$self{'id'}');", 1) ) {return 1;} else {return;} 
}

# метод удаления из листинга на индексной странице анонса объекта группы
sub delete_in_listing {
    my ( $self ) = @_;
    if ( sql("DELETE FROM groups_list WHERE group_id = '$$self{'id'}';", 1) ) {return 1;} else {return;}
}


# метод очистки данных объекта в кеше
sub clear_cache_data {
    my ( $self ) = @_;
    my $key = $SUF_DATA . $self->{'id'};
    mem_get()->delete($key);
    return;
}

sub clear_cache_data_image {
    my ( $self ) = @_;
    my $key = $SUF_IMAGE . $self->{'id'};
    mem_get()->delete($key);
    return;
}

sub clear_cache_data_file {
    my ( $self ) = @_;
    my $key = $SUF_FILE . $self->{'id'};
    mem_get()->delete($key);
    return;
}

sub clear_cache_data_preview {
    my ( $self ) = @_;
    my $key = $SUF_PREVIEW . $self->{'id'};
    mem_get()->delete($key);
    return;
}


# аксессоры
sub id           { return shift->{id}; }
sub title        { return shift->{title}; }
sub title_orig   { return shift->{title_orig}; }
sub description  { return shift->{description}; }
sub year         { return shift->{year}; }
sub allow_age    { return shift->{allow_age}; }
sub rate_count   { return shift->{rate_count}; }
sub rate_val     { return shift->{rate_val}; }
sub rate_our     { return shift->{rate_our}; }
sub owner_id     { return shift->{owner_id}; }
sub kinopoisk_id { return shift->{kinopoisk_id}; }
sub is_serial    { return shift->{is_serial}; }
sub genres       { return shift->{genres}; }
sub countries    { return shift->{countries}; }
sub directors    { return shift->{directors}; }
sub actors       { return shift->{actors}; }


# локальные функции
# локально: проверка на идентификатор группы
sub _check_group_id {
    my ($group_id) = @_;
    if ($group_id !~ m/^\d+$/) {return;}
    else {
        # пытаемся проверить данные в кеше
        my $key = $SUF_DATA . $group_id;
        my $memcached = mem_get()->get($key);
        if ($memcached) {
            # данные нашлись, значит идентификатор существует
            return 1;
        }
        
        # данные в кеше не нашлись, проверяем в базе и на основании результата, делаем ответ
        my $sql = sql("SELECT id FROM groups_data WHERE id = '$group_id';");
        !$$sql[0] ? return : return 1;
    }
}

1;
