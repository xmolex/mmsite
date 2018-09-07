package Mmsite::Lib::Files;
################################################################################
#  Управление файлами
################################################################################
# настройки
################################################################################
my $MEM_SUF_FILES_DATA         = 'file_data_'; # memcached: суффикс ключа данных файла
my $MEM_SUF_FILES_DATA_VERSION = 'file_data_version_'; # memcached: суффикс ключа данных версии файла
################################################################################
use Modern::Perl;
use utf8;
use JSON::XS;
use File::Copy;
use Digest::MurmurHash qw(murmur_hash);
use Data::Structure::Util qw( unbless );
use Mmsite::Lib::Vars;
use Mmsite::Lib::Subs;
use Mmsite::Lib::Db;
use Mmsite::Lib::Mem;
use Mmsite::Lib::Ffmpeg;
use Mmsite::Lib::Members::View;

# инициализируем объект json
my $json_xs = JSON::XS->new();
$json_xs->utf8();

# инициализируем хэш для хранения созданных объектов
my %OBJECT;

# создаем экземпляр
# image_id: 0 - создать новый, >0 - существующий
# image_type: 2 - постеры, 3 - кадры, 5 - фото
sub new {
    my ( $class, $file_id ) = @_;
    
    # если объект уже создан, то отдаем
    return $OBJECT{$file_id} if $OBJECT{$file_id};

    # проверка на допустимый идентификатор
    return unless _check_file_id($file_id);
    
    # создаем объект
    my $self = { id => $file_id };
    $OBJECT{$file_id} = bless $self, $class;
    return( $OBJECT{$file_id} );
}

# добавление нового файла
# возвращаем сообщение об ошибке или объект
sub create {
    my ( $class, $self ) = @_;
    
    # пытаемся создать объект и если успешно, то возвращаем объект, а если нет, то строку с ошибкой
    
    # проверка на имя файла
    return "error: file name is empty" unless $$self{'source_name'};
    
    # проверка на файл на диске
    return "error: file '$$self{'source_name'}' not found" unless ( -f $$self{'source_path'} );
    
    # проверка на тип файла (0-файл, 1-трейлер, 2-субтитры)
    if (! $$self{'type'}) {
        $$self{'type'} = 0;
    }
    else {
        return "error: file '$$self{'source_name'}' has broken type" if $$self{'type'} !~ m/^(0|1|2)$/;
    }
    
    # проверка на перевод
    if (! $$self{'translate'}) {
        $$self{'translate'} = 0;
    }
    else {
        return "error: file '$$self{'source_name'}' has broken translate" if $$self{'type'} !~ m/^(0|1|2)$/;
    }
    
    # проверка на родителя (на идентификатор файла к которому привязан данный файл)
    if (! $$self{'file_id'}) {
        $$self{'file_id'} = 0;
    }
    else {
        return "error: file '$$self{'source_name'}' has broken parent" if $$self{'file_id'} !~ m/^\d+$/;
    }
    
    # проверка на группу
    if (! $$self{'parent_id'}) {
        $$self{'parent_id'} = 0;
    }
    else {
        return "error: file '$$self{'source_name'}' has broken parent_id" if $$self{'parent_id'} !~ m/^\d+$/;
    }
    
    # собираем необходимую информацию
    $$self{'title'} = $$self{'source_name'} unless $$self{'title'};
    $$self{'owner_id'} = -1 unless $$self{'owner_id'};
    my @size = stat $$self{'source_path'};
    $$self{'size'} = $size[7] || 0;
    
    # проверяем нет ли уже такого файла в файловом хранилище
    my $rand_name = '';
    my $path_destination = $PATH_FILES . '/' . $$self{'source_name'};
    if (-f $path_destination) {
        # переименовываем наш файл, с добавлением случайных данных в название
        $rand_name = murmur_hash(time()) . '_';
        $path_destination = $PATH_FILES . '/' . $rand_name . $$self{'source_name'};
    }
    
    # копируем файл в директорию хранилища
    copy( $$self{'source_path'}, $path_destination );
    return "error: don't can move file '$$self{'source_name'}' in storage" unless (-f $path_destination);
    
    # меняем название файла, если оно менялось
    if ($rand_name) {
        $$self{'source_name'} = $rand_name . $$self{'source_name'};
    }
    
    # защита от sql'inj
    $$self{'title'}       = tr_sql $$self{'title'};
    $$self{'source_name'} = tr_sql $$self{'source_name'};
    $$self{'description'} = tr_sql $$self{'description'};  
    
    # добавляем файл в базу
    my $sql = sql( qq|
                       INSERT INTO files
                           ( type, file_id, parent_id, title, file, size, owner_id, translate, description )
                       VALUES 
                           ( '$$self{'type'}', '$$self{'file_id'}', '$$self{'parent_id'}', '$$self{'title'}', '$$self{'source_name'}', '$$self{'size'}', '$$self{'owner_id'}', '$$self{'translate'}', '$$self{'description'}' )
                       RETURNING id;
                 |);
    
    if (!$$sql[0]) {
        # не удалось добавить в базу, удаляем перенесенный исходник и выходим
        unlink( $path_destination );
        return "error: don't add file '$$self{'source_name'}' info to database";
    }
    
    # успешно добавлено
    $$self{'id'} = $$sql[0];
    
    # если был указан родитель, то сбрасываем ему кеш
    if ( $$self{'file_id'} ) {
        my $obj_file = Mmsite::Lib::Files->new($$self{'file_id'});
        if ($obj_file) {
            $obj_file->clear_cache_data();
        }
    }
    
    # сбрасываем кеш непросмотренных файлов для объекта группы
    Mmsite::Lib::Members::View::view_clear_all_cache_data_for_group($$self{'parent_id'});
    
    # возвращаем объект       
    $OBJECT{ $$self{'id'} } = bless $self, $class;
    return $OBJECT{ $$self{'id'} };
}

# получаем свойства объекта группы, возвращаем истину или ложь
sub get {
    my ($self) = @_;
    
    # проверяем версию данных в кеше
    my $version_key = $MEM_SUF_FILES_DATA_VERSION . $self->{'id'};
    my $version_val = mem_get()->get($version_key);
    if ( $version_val && $version_val == $self->{'data_version'} ) {
        # актуальные данные уже в памяти
        return 1;
    }
    else {
        # пытаемся взять данные из кеша
        my $json_decode;
        my $key = $MEM_SUF_FILES_DATA . $self->{'id'};
        my $memcached = mem_get()->get($key);
        if ($memcached) {
            # данные есть, распарсиваем
            on_utf8(\$memcached);
            if (eval { $json_decode = $json_xs->decode($memcached); }) {
                # удалось распарсить, заносим данные в свойства объекта
                while ( my( $key, $val ) = each(%$json_decode) ) {
                    $self->{$key} = $val;
                }
                
                # помечаем, что данные у нас определенной версии
                $self->{'data_version'} = $version_val;
                
                return 1;
            }
        }
    }
    
    # берем данные из базы
    my $sql = sql("SELECT id,type,title,file,size,is_web,count_download,count_view,owner_id,translate,description,res_x,res_y,other,duration,file_id,parent_id,source,source_time FROM files WHERE id = '$self->{'id'}';");
    return unless $$sql[0];
    
    # данные есть, заносим данные в промежуточный хэш для json, т.к. он не умеет работать с bless свойствами
    my %hash;
    $hash{'id'}             = $$sql[0];
    $hash{'type'}           = $$sql[1];
    $hash{'title'}          = $$sql[2];
    $hash{'file'}           = $$sql[3];
    $hash{'size'}           = $$sql[4];
    $hash{'is_web'}         = $$sql[5];
    $hash{'count_download'} = $$sql[6];
    $hash{'count_view'}     = $$sql[7];
    $hash{'owner_id'}       = $$sql[8];
    $hash{'translate'}      = $$sql[9];
    $hash{'description'}    = $$sql[10];
    $hash{'res_x'}          = $$sql[11];
    $hash{'res_y'}          = $$sql[12];
    $hash{'other'}          = $$sql[13];
    $hash{'duration'}       = $$sql[14];
    $hash{'file_id'}        = $$sql[15];
    $hash{'parent_id'}      = $$sql[16];
    $hash{'source'}         = $$sql[17];
    $hash{'source_time'}    = $$sql[18];
    
    # собираем зависимые файлы
    $sql = sql("SELECT id FROM files WHERE file_id = '$self->{'id'}';");
    $hash{'dependent'} = $sql;
    
    # данные есть, заносим данные в свойства объекта
    while ( my( $key, $val ) = each(%hash) ) {
        $self->{$key} = $val;
    }

    # заносим данные в хэш
    my $key = $MEM_SUF_FILES_DATA . $self->{'id'};
    my $memcached = $json_xs->encode(\%hash);
    mem_get()->delete($key);
    mem_get()->add( $key, $memcached );
    # устанавливаем текущую версию
    mem_get()->incr($version_key);
    $self->{'data_version'} = mem_get()->get($version_key);
    
    return 1;    
}


# метод изменения объекта файла
sub set {
    my ( $self, $param, $value ) = @_;
    
    # получаем информацию об объекте
    $self->get();
    
    if ( $param !~ m/(file|type|file_id|title|count_download|count_view|translate|description|res_x|res_y|other|parent_id|duration|is_web|size|source|source_time)/ ) { return(); }
    
    # пробуем установить
    my $sql_val = "'" . tr_sql($value) . "'";
    
    # проверка на булевые типы
    if ($param eq 'is_web') {
        if ($value) {$sql_val = 'TRUE';} else {$sql_val = 'FALSE';}
    }
    
    # ставим
    if ( sql( "UPDATE files SET \"$param\" = $sql_val WHERE id = '$self->{'id'}';", 1 ) ) {
        # установлено
        $self->{$param} = $value;
        
        # чистим кеш
        $self->clear_cache_data();
        
        return 1; 
    }
    else {
        # не удалось установить
        return;
    }
}

    

# удаление файла
# возвращаем булево
sub delete {
    my ($self) = @_;
    
    # получаем информацию об объекте
    $self->get();
    
    # удаляем информацию о просмотренных файлах у всех пользователей
    Mmsite::Lib::Members::View::view_delete_force($self->{'id'});
    
    # сбрасываем кеш непросмотренных файлов для объекта группы
    Mmsite::Lib::Members::View::view_clear_all_cache_data_for_group($self->{'parent_id'});

    # удаляем инфо из базы
    if ( sql( "DELETE FROM files WHERE id='$self->{'id'}';", 1 ) ) {
    
        # удаляем информацию о настройках кодирования
        sql( "DELETE FROM files_conv_setting WHERE file_id = '$self->{'id'}';" , 1);
        
        # удаляем файлы
        my $path = $PATH_FILES . '/' . $self->{'file'};
        if (-f $path) {unlink $path;}
        
        # удаляем оригинал, если есть
        if ($self->{'source'}) {
            $path = $PATH_FILES_SOURCE . '/' . $self->{'source'};
            if (-f $path) {unlink $path;}
        }
        
        # чистим кеш
        $self->clear_cache_data();
        $self->clear_cache_data_version();
        
        # если был указан родитель, то сбрасываем ему кеш
        if ( $self->{'file_id'} ) {
            my $obj_file = Mmsite::Lib::Files->new($self->{'file_id'});
            if ($obj_file) {
                $obj_file->clear_cache_data();
            }
        }

        # удаляем объект и данные
        my $id = $self->{'id'};
        unbless $self;
        %$self = ();
        $OBJECT{$id} = 0;
        
        return 1;
    }

    return;
}

# создаем копию исходника ( и файлы субтитры ), если ее еще нет
sub create_source_file {
    my ($self) = @_;
    
    # получаем информацию об объекте
    $self->get();
    
    if ($self->{'source'}) {
        # переменная есть, проверяем наличие на диске
        if ( -f $PATH_FILES_SOURCE . $self->{'source'} ) {
            # на диске файл есть, меняем время последнего обращения и выходим
            $self->set( 'source_time', time() );
            return 1;
        }
    }
    
    # исходника нет, создаем
    copy $PATH_FILES . $self->{'file'}, $PATH_FILES_SOURCE . $self->{'file'};
    unless ( -f $PATH_FILES_SOURCE . $self->{'file'} ) {
        return 0;
    }
        
    # указываем, что есть исходник и время его добавления
    $self->set( 'source', $self->{'file'} );
    $self->set( 'source_time', time() );
        
    # т.к. это первое пережимание, то нужно извлечь файлы субтитров, если они есть
    $self->clone_subtitles_from_video_file();
    
    return 1;
}

# пережимаем файл в веб формат, получая параметры пережимания и флаг обязательного пережимания
# возвращаем истину при удаче, либо ложь и сообщение об ошибке
sub conv_to_web {

    my ( $self, $force ) = @_;
    
    # получаем информацию об объекте
    $self->get();
    
    # расширение файла
    return( 0, 'file is not video' ) unless Mmsite::Lib::Ffmpeg::is_video_extension( get_extension $self->{'file'} );

    # создаем исходник и субтитры, если необходимо
    return( 0, 'do not create source file' ) unless $self->create_source_file();
    
    # объявляем используемые переменные
    my $file_name        = $self->{'file'};               # имя файла
    my $file_name_conv   = $self->{'file'} . '.mp4';      # имя обработанного файла
    my $web_file         = $PATH_FILES . $file_name_conv; # путь к обработанному файлу
    my $web_img          = $PATH_FILES_IMG . $self->{'id'} . '.jpg'; # путь к кадру превьюшке
    
    my ( $ffmpeg, $error) = Mmsite::Lib::Ffmpeg->new( $PATH_FILES_SOURCE . $self->{'source'} );
    return( 0, $error ) unless $ffmpeg; # не удалось создать объект для работы
    
    # жмем
    my ( $result, $path_file, $path_img ) = $ffmpeg->conv( $self, $force );
    return( 0, $path_file ) unless $result; # не удалось, в $path_file у нас сообщение об ошибке
    
    # в $path_file у нас путь к пережатому файлу во временной директории
    # в $path_img у нас путь к изображению превьюшке во временной директории
    # переносим в директории хранения попутно меняя имена на требуемые
    move( $path_file, $web_file );
    move( $path_img, $web_img );
    
    unless ( -f $web_file && -f $web_img ) {
        # не удалось перенести
        unlink $path_file;
        unlink $path_img;
        return( 0, 'do not move convert file');
    }

    # получаем данные по новому видео
    ( $ffmpeg, $error) = Mmsite::Lib::Ffmpeg->new( $web_file );
    return( 0, $error ) unless $ffmpeg; # не удалось создать объект для работы
    
    ( $result, $error ) = $ffmpeg->get();
    return( 0, $error ) unless $result; # не удалось получить данные
    
    # переводим продолжительность в текстовый формат
    my $duration_text = Mmsite::Lib::Ffmpeg::conv_sec_in_text( $ffmpeg->video_duration );
    
    # получаем размер нового видео
    my @stat = stat $web_file;
    my $size = $stat[7] || 0;
    
    # сохраняем данные
    $self->set( 'file', $file_name_conv );
    $self->set( 'is_web', 1 );
    $self->set( 'duration', $duration_text );
    $self->set( 'res_x', $ffmpeg->video_width );
    $self->set( 'res_y', $ffmpeg->video_height );
    $self->set( 'size', $size );
    if ($self->{'title'} eq $file_name) {
        $self->set( 'title', $file_name_conv );
    }
    
    # удаляем изначальный файл
    unlink( $PATH_FILES . $file_name );
    
    # чистим кеш
    $self->clear_cache_data();
    
    return 1;
}


# метод извлечения субтитров из видео файла с последующим их сохранением и привязкой к данному видеофайлу
# работает только с исходным файлом, поэтому запускать ее необходимо после функции conv_to_web
# возвращает идентификаторы добавленных файлов, либо ложь и сообщение об ошибке
sub clone_subtitles_from_video_file {
    my ( $self ) = @_;
    
    # получаем информацию об объекте
    $self->get();
    
    # проверяем наличие исходного файла
    return( 0, 'source file not found' ) unless $self->{'source'};
    
    my $path_source_video = $PATH_FILES_SOURCE . $self->{'source'};
    
    return( 0, 'source file not found' ) unless (-f $path_source_video);
    
    # пытаемся объявить работу с ffmpeg
    my ( $ffmpeg, $error) = Mmsite::Lib::Ffmpeg->new($path_source_video);
    return( 0, $error ) unless $ffmpeg; # не удалось создать объект для работы
    
    # извлекаем субтитры
    my $result = $ffmpeg->clone_subtitles();
    
    # проходимся по временным файлам и добавляем их
    if ( scalar(@$result) ) {
        foreach my $el (@$result) {
            if (-f $$el{'path'}) {
                # файл существует, добавляем
                # формируем структуру для создания файла
                my $hash = {
                               'title'       => $$el{'title'},
                               'source_path' => $$el{'path'},
                               'source_name' => $$el{'name'},
                               'parent_id'   => $self->{'parent_id'},
                               'type'        => 2, # тип субтитров
                               'file_id'     => $self->{'id'}
                };
            
                # создаем
                my $file = Mmsite::Lib::Files->create($hash);
                if ($file) {
                    # удаляем временный файл субтитров
                    if (-f $$el{'path'}) {
                        unlink $$el{'path'};
                    }
                }
                
            }
        }
    }
    
    # чистим кеш
    $self->clear_cache_data();

    return 1;
}

# получаем настройки по файлу для сжатия
sub get_conv_setting {
    my ( $self ) = @_;
    
    # получаем информацию об объекте
    $self->get();
    
    # расширение файла
    return( 0, 'file is not video' ) unless Mmsite::Lib::Ffmpeg::is_video_extension( get_extension $self->{'file'} );
    
    # т.к. данный функционал будет использоваться редко, будем работать с базой
    my $sql = sql("SELECT file_id,status,change_time,set_map,set_b,set_async,set_af,set_s,set_ss,set_t FROM files_conv_setting WHERE file_id='$self->{'id'}';");

    # мы должны объявить всеравно, поэтому будем присваивать значения, даже, если ничего не получили из базы    
    $self->{'conv_status'}      = $$sql[1];
    $self->{'conv_change_time'} = $$sql[2];
    $self->{'conv_set_map'}     = $$sql[3];
    $self->{'conv_set_b'}       = $$sql[4];
    $self->{'conv_set_async'}   = $$sql[5];
    $self->{'conv_set_af'}      = $$sql[6];
    $self->{'conv_set_s'}       = $$sql[7];
    $self->{'conv_set_ss'}      = $$sql[8];
    $self->{'conv_set_t'}       = $$sql[9];
    
    return 1;
}

# устанавливаем свойства, без какой-либо внешней модификации 
sub set_conv {
    my ( $self, $key, $value ) = @_;
    return unless $key;
    $self->{$key} = $value;
    return 1;
}

# записываем настройки по файлу для сжатия, возвращаем истину или ложь и сообщение об ошибке
sub set_conv_setting {
    my ( $self ) = @_;
    
    # получаем информацию об объекте
    $self->get();
    
    # проверяем
    return( 0, 'error: статус может быть только в диапазоне от 0-3' )                             if $self->{'conv_status'}  !~ m/^[0123]$/;
    return( 0, 'error: аудиодорожка должна быть указана только в виде числа' )                    if $self->{'conv_set_map'} !~ m/^\d+$/;
    return( 0, 'error: битрейт видео должен быть указан только в виде числа и указывается в Kb' ) if $self->{'conv_set_b'}   !~ m/^\d+$/;
    
    # объявляем новый хэшь для промежуточного хранения данных, чтобы не модифицировать исходные
    my %conv;
    $conv{'conv_status'}  = $self->{'conv_status'};
    $conv{'conv_set_map'} = $self->{'conv_set_map'};
    $conv{'conv_set_b'}   = $self->{'conv_set_b'};
    
    
    # остальное не обязательно проверять, но нужно подвести под верный формат
    unless ( defined $self->{'conv_set_async'} ) {
        $conv{'conv_set_async'} = 'NULL';
    }
    else {
        $conv{'conv_set_async'} = tr_sql($self->{'conv_set_async'});
        $conv{'conv_set_async'} = "'" . $conv{'conv_set_async'} . "'";
    }
    
    unless ( defined $self->{'conv_set_af'} ) {
        $conv{'conv_set_af'} = 'NULL';
    }
    else {
        $conv{'conv_set_af'} = tr_sql($self->{'conv_set_af'});
        $conv{'conv_set_af'} = "'" . $conv{'conv_set_af'} . "'";
    }
    
    unless ( defined $self->{'conv_set_s'} ) {
        $conv{'conv_set_s'} = 'NULL';
    }
    else {
        $conv{'conv_set_s'} = tr_sql($self->{'conv_set_s'});
        $conv{'conv_set_s'} = "'" . $conv{'conv_set_s'} . "'";
    }
    
    unless ( defined $self->{'conv_set_ss'} ) {
        $conv{'conv_set_ss'} = 'NULL';
    }
    else {
        $conv{'conv_set_ss'} = tr_sql($self->{'conv_set_ss'});
        $conv{'conv_set_ss'} = "'" . $conv{'conv_set_ss'} . "'";
    }
    
    unless ( defined $self->{'conv_set_t'} ) {
        $conv{'conv_set_t'} = 'NULL';
    }
    else {
        $conv{'conv_set_t'} = tr_sql($self->{'conv_set_t'});
        $conv{'conv_set_t'} = "'" . $conv{'conv_set_t'} . "'";
    }
    
    $conv{'conv_change_time'} = time();
    
    # удаляем из базы, если есть
    unless ( sql( "DELETE FROM files_conv_setting WHERE file_id = '$self->{'id'}';" , 1 ) ) {
        return( 0, 'error: ошибка базы данных' );
    }
    
    # добавляем в базу
    unless ( sql( qq|
                         INSERT INTO files_conv_setting 
                             ( file_id, status, change_time, set_map, set_b, set_async, set_af, set_s, set_ss, set_t )
                         VALUES
                             ( 
                                 $self->{'id'}, $conv{'conv_status'}, $conv{'conv_change_time'}, $conv{'conv_set_map'}, $conv{'conv_set_b'},
                                 $conv{'conv_set_async'}, $conv{'conv_set_af'}, $conv{'conv_set_s'}, $conv{'conv_set_ss'}, $conv{'conv_set_t'}
                             );
                     |, 1 ) ) {
        return( 0, 'error: ошибка базы данных' );
    }

    return 1;
}
    


# метод очистки данных объекта в кеше
sub clear_cache_data {
    my ( $self ) = @_;
    my $key = $MEM_SUF_FILES_DATA . $self->{'id'};
    mem_get()->delete($key);
    return;
}

sub clear_cache_data_version {
    my ( $self ) = @_;
    my $key = $MEM_SUF_FILES_DATA_VERSION . $self->{'id'};
    mem_get()->delete($key);
    return;
}



# аксессоры
sub id               { return shift->{id}; }
sub type             { return shift->{type}; }
sub title            { return shift->{title}; }
sub file             { return shift->{file}; }
sub size             { return shift->{size}; }
sub is_web           { return shift->{is_web}; }
sub count_download   { return shift->{count_download}; }
sub count_view       { return shift->{count_view}; }
sub owner_id         { return shift->{owner_id}; }
sub translate        { return shift->{translate}; }
sub description      { return shift->{description}; }
sub res_x            { return shift->{res_x}; }
sub res_y            { return shift->{res_y}; }
sub other            { return shift->{other}; }
sub duration         { return shift->{duration}; }
sub file_id          { return shift->{file_id}; }
sub parent_id        { return shift->{parent_id}; }
sub source           { return shift->{source}; }
sub source_time      { return shift->{source_time}; }
sub dependent        { return shift->{dependent}; }
sub conv_status      { return shift->{conv_status}; }
sub conv_change_time { return shift->{conv_change_time}; }
sub conv_set_map     { return shift->{conv_set_map}; }
sub conv_set_b       { return shift->{conv_set_b}; }
sub conv_set_async   { return shift->{conv_set_async}; }
sub conv_set_af      { return shift->{conv_set_af}; }
sub conv_set_s       { return shift->{conv_set_s}; }
sub conv_set_ss      { return shift->{conv_set_ss}; }
sub conv_set_t       { return shift->{conv_set_t}; }



# локальные функции
# локально: проверка на идентификатор
sub _check_file_id {
    my ($file_id) = @_;
    
    if ($file_id !~ m/^\d+$/) {return();}
    else {
        # пытаемся проверить данные в кеше
        my $key = $MEM_SUF_FILES_DATA . $file_id;
        my $memcached = mem_get()->get($key);
        if ($memcached) {
            # данные нашлись, значит идентификатор существует
            return 1;
        }
        
        # данные в кеше не нашлись, проверяем в базе и на основании результата, делаем ответ
        my $sql = sql("SELECT id FROM files WHERE id = '$file_id';");
        
        if ( !$$sql[0] ) { return; } else { return 1; }
    }
}


1;