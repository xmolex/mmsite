#################################################################
#  Управление изображениями (постеры, кадры, фото)
#################################################################
package Mmsite::Lib::Images;

################################################################################
# настройки
################################################################################
my $MEM_SUF_IMG_DATA = 'image_data_'; # memcached: суффикс ключа данных изображения
################################################################################

use Modern::Perl;
use utf8;
use Image::Magick;
use JSON::XS;
use File::Copy;
use Data::Structure::Util qw( unbless );
use Mmsite::Lib::Vars;
use Mmsite::Lib::Db;
use Mmsite::Lib::Mem;

# инициализируем объект json
my $json_xs = JSON::XS->new();
$json_xs->utf8();

# инициализируем хэш для хранения созданных объектов
my %OBJECT;

# создаем экземпляр
# image_id: 0 - создать новый, >0 - существующий
# image_type: 2 - постеры, 3 - кадры, 5 - фото
sub new {
    my ( $class, $image_id ) = @_;
    
    # если объект уже создан, то отдаем
    return $OBJECT{$image_id} if $OBJECT{$image_id};
    
    # проверка на допустимый идентификатор
    return unless ( _check_image_id($image_id) );
    
    # создаем объект
    my $self = { id => $image_id };
    $OBJECT{$image_id} = bless $self, $class;
    return( $OBJECT{$image_id} );
}

# получаем свойства объекта группы, возвращаем истину или ложь
sub get {
    my ($self) = @_;
    
    # пытаемся взять данные из кеша
    my $json_decode;
    my $key = $MEM_SUF_IMG_DATA . $self->{'id'};
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
    my $sql = sql("SELECT id,type,parent_id,owner_id,title,name FROM images WHERE id = '$self->{'id'}';");
    return unless $$sql[0];
    
    # данные есть, заносим данные в промежуточный хэш для json, т.к. он не умеет работать с bless свойствами
    my $url = $URL_POSTERS;
    if ($$sql[1] == 3) {$url = $URL_SHOTS;}
    elsif ( $$sql[1] == 4 || $$sql[1] == 5 ) {$url = $URL_PHOTOS;}
    
    my %hash;
    $hash{'id'}         = $$sql[0];
    $hash{'type'}       = $$sql[1];
    $hash{'parent_id'}  = $$sql[2];
    $hash{'owner_id'}   = $$sql[3];
    $hash{'title'}      = $$sql[4];
    $hash{'name'}       = $$sql[5];
    $hash{'url_orig'}   = $url . '/' . $IMG_SUF_ORIG . $$sql[5] . '.jpg';
    $hash{'url_std'}    = $url . '/' . $IMG_SUF_STD  . $$sql[5] . '.jpg';
    $hash{'url_mini'}   = $url . '/' . $IMG_SUF_MINI . $$sql[5] . '.jpg';
    
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


    
# создание нового изображения
# возвращаем сообщение об ошибке или объект
sub create {
    my ( $class, $self ) = @_;
    
    # проверка на имя файла
    return "error: file name is empty" unless $$self{'source_name'};
    
    # проверка на допустимый тип
    return "error: type broken" if $$self{'type'} !~ m/^(2|3|5)$/;
    
    # проверка на существование исходника
    return "error: source file '$$self{'source_name'}' not found" unless (-f $$self{'source_path'});
   
    # проверка на верный формат исходника
    my $format = _check_image_file( $$self{'source_path'} );
    return "error: source file '$$self{'source_name'}' not jpg,png,gif" unless $format;
    
    # проверка на группу
    if (! $$self{'parent_id'}) {$$self{'parent_id'} = 0;}
    else {
        return "error: file '$$self{'source_name'}' has broken parent_id" if $$self{'parent_id'} !~ m/^\d+$/;
    }
    
    # проверка на владельца
    $$self{'owner_id'} = -1 unless $$self{'owner_id'};
    
    # проверка на название
    $$self{'title'} = 'image' unless $$self{'title'};
    
    # заполняем переменные в зависимости от типа
    my $res_x       = 0;                      # ширина картинки в пикселях
    my $res_y       = 0;                      # высота картинки в пикселях
    my $res_x_mini  = 0;                      # ширина картинки в пикселях (мини)
    my $res_y_mini  = 0;                      # высота картинки в пикселях (мини)
    my $path_dir    = '';                     # директория для хранения
    my $target_name = get_uniq_filename(); # случайное имя для создаваемого файла
    
    if ( $$self{'type'} == 5 ) {
        # фото
        $res_x      = $IMG_PHOTO_X;
        $res_y      = $IMG_PHOTO_Y;
        $res_x_mini = $IMG_PHOTO_MINI_X;
        $res_y_mini = $IMG_PHOTO_MINI_Y;
        $path_dir   = $PATH_PHOTOS;
    }
    elsif ( $$self{'type'} == 3 ) {
        # кадры
        $res_x      = $IMG_SHOT_X;
        $res_y      = $IMG_SHOT_Y;
        $res_x_mini = $IMG_SHOT_MINI_X;
        $res_y_mini = $IMG_SHOT_MINI_Y;
        $path_dir   = $PATH_SHOTS;
    }
    else {
        # постеры
        $res_x      = $IMG_POSTER_X;
        $res_y      = $IMG_POSTER_Y;
        $res_x_mini = $IMG_POSTER_MINI_X;
        $res_y_mini = $IMG_POSTER_MINI_Y;
        $path_dir   = $PATH_POSTERS;
    } 

    my $target_path_orig = "$path_dir/" . $IMG_SUF_ORIG . "$target_name.jpg"; # путь к оригинальному файлу изображения
    my $target_path_std  = "$path_dir/" . $IMG_SUF_STD  . "$target_name.jpg"; # путь к стандартному файлу изображения
    my $target_path_mini = "$path_dir/" . $IMG_SUF_MINI . "$target_name.jpg"; # путь к превью изображения
    
    my $imgk = Image::Magick->new;
    
    # переводим исходник в jpg и переносим в директорию для хранения
    if ($format ne 'jpg') {
        $imgk->Read( $$self{'source_path'} );
        $imgk->Write( $target_path_orig );
    }
    else {
        copy( $$self{'source_path'}, $target_path_orig )
    }
    
    # защита от sql'inj
    $target_name    = tr_sql $target_name;
    $$self{'title'} = tr_sql $$self{'title'};
    
    # на этом этапе у нас должен находиться исходный файл в хранилище, добавим в базу
    my $sql = sql("INSERT INTO images ( type, parent_id, owner_id, title, name ) VALUES ( $$self{'type'}, $$self{'parent_id'}, $$self{'owner_id'}, '$$self{'title'}', '$target_name' ) RETURNING id;");
    if (!$$sql[0]) {
        # не удалось добавить в базу, удаляем перенесенный исходник и выходим
        unlink( $target_path_orig );
        return "error: don't add image file '$$self{'source_name'}' info to database";
    }
    
    $$self{'id'} = $$sql[0];
    
    # создаем стандартное и превью отображение из исходника
    $imgk = Image::Magick->new; # создаем новый объект, т.к. без него глюки 
    $imgk->Read( $target_path_orig );
    my ( $source_res_x, $source_res_y ) = $imgk->Get('base-columns','base-rows');
    my ( $result_x, $result_y );

    if ($source_res_x > $res_x) {
        $result_y = int( ($source_res_y * $res_x) / $source_res_x );
        $result_x = $res_x;
    }
    if ($source_res_y > $res_y) {
        $result_x = int( ($res_y * $source_res_x) / $source_res_y );
        $result_y = $res_y; 
    }
    $imgk->Resize( geometry=>'geometry', width=>$result_x, height=>$result_y );
    $imgk->Write( $target_path_std );

    $imgk = Image::Magick->new; # создаем новый объект, т.к. без него глюки 
    $imgk->Read( $target_path_orig );
    if ($source_res_x > $res_x_mini) {
        $result_y = int( ($source_res_y * $res_x_mini) / $source_res_x );
        $result_x = $res_x_mini;
    }
    if ($source_res_y > $res_y_mini) {
        $result_x = int( ($res_y_mini * $source_res_x) / $source_res_y );
        $result_y = $res_y_mini; 
    }
    $imgk->Resize( geometry=>'geometry', width=>$result_x, height=>$result_y );
    $imgk->Write( $target_path_mini );

    if (!-f $target_path_std || !-f $target_path_mini) {
        # не удалось создать превью или стандартное изображение, удаляем файлы, удаляем запись с базы и выходим
        unlink( $target_path_orig );
        unlink( $target_path_std )  if (-f $target_path_std);
        unlink( $target_path_mini ) if (-f $target_path_mini);
        sql("DELETE FROM images WHERE id='$$self{'id'}';",1);
        return "error: don't create std or mini image file";
    }
    
    $OBJECT{ $$self{'id'} } = bless $self, $class;
    return( $OBJECT{ $$self{'id'} } );
}


# метод изменения объекта изображения
sub set {
    my ( $self, $param, $value ) = @_;
    
    # получаем информацию об объекте
    $self->get();
    
    return if $param !~ m/(type|owner_id)/;
    
    # пробуем установить
    my $sql_val = tr_sql $value;
    if ( sql( "UPDATE images SET \"$param\" = '$sql_val' WHERE id = '$self->{'id'}';", 1 ) ) {
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


# удаление изображения
# возвращаем булево
sub delete {
    my ($self) = @_;
    
    # получаем информацию об объекте
    $self->get();

    # удаляем инфо из базы
    if ( sql( "DELETE FROM images WHERE id='$self->{'id'}';", 1 ) ) {
        
        # удаляем файлы
        my $path = $PATH_POSTERS;
        if ( $self->{'type'} == 3) {$path = $PATH_SHOTS;}
        elsif ( $self->{'type'} == 4 || $self->{'type'} == 5 ) {$path = $PATH_PHOTOS;}
    
        my $path_orig = $path . '/' . $IMG_SUF_ORIG . $self->{'name'} . '.jpg';
        my $path_std  = $path . '/' . $IMG_SUF_STD  . $self->{'name'} . '.jpg';
        my $path_mini = $path . '/' . $IMG_SUF_MINI . $self->{'name'} . '.jpg';
    
        if (-f $path_orig) {unlink($path_orig);}
        if (-f $path_std)  {unlink($path_std); }
        if (-f $path_mini) {unlink($path_mini);}
        
        # чистим кеш
        $self->clear_cache_data();
        
        # удаляем объект и данные
        my $id = $self->{'id'};
        unbless $self;
        %$self = ();
        $OBJECT{$id} = 0;
        
        return 1;
    }

    return;
}

# метод очистки данных объекта в кеше
sub clear_cache_data {
    my ( $self ) = @_;
    my $key = $MEM_SUF_IMG_DATA . $self->{'id'};
    mem_get()->delete($key);
    return;
}


# аксессоры
sub id        { return shift->{id}; }
sub type      { return shift->{type}; }
sub parent_id { return shift->{parent_id}; }
sub owner_id  { return shift->{owner_id}; }
sub title     { return shift->{title}; }
sub name      { return shift->{name}; }
sub url_orig  { return shift->{url_orig}; }
sub url_std   { return shift->{url_std}; }
sub url_mini  { return shift->{url_mini}; }


# локальные функции
# локально: проверка на идентификатор
sub _check_image_id {
    my ($image_id) = @_;
    
    if ($image_id !~ m/^\d+$/) {return();}
    else {
        # пытаемся проверить данные в кеше
        my $key = $MEM_SUF_IMG_DATA . $image_id;
        my $memcached = mem_get()->get($key);
        if ($memcached) {
            # данные нашлись, значит идентификатор существует
            return 1;
        }
        
        # данные в кеше не нашлись, проверяем в базе и на основании результата, делаем ответ
        my $sql = sql("SELECT id FROM images WHERE id = '$image_id';");
        
        if ( !$$sql[0] ) { return; } else { return 1; }
    }
}

# локально: функция определения типа файла по содержимому
# получаем путь к файлу и выдаем jpg,gif,png или null
sub _check_image_file {
    my $hex_png = pack 'H*', join '', qw (89 50 4E 47 0D 0A 1A 0A 00 00 00 0D 49 48 44 52);
    my $hex_gif = pack 'H*', join '', qw (47 49 46);
    my $hex_jpg = pack 'H*', join '', qw (FF D8 FF);
    open my $fh, "<", $_[0];
    return unless $fh;
    binmode $fh;
    
    # анализируем начальные данные файла на соотвествующий тип
    my $buf;
    seek( $fh, 0, 0 );
    read( $fh, $buf, 16 );
    if ($buf eq $hex_png) {return "png";}
    else {
        seek( $fh, 0, 0 );
        read( $fh, $buf, 3 );
        if ($buf eq $hex_gif) {return "gif";}
        if ($buf eq $hex_jpg) {return "jpg";}
    }
    close $fh;
    return;
}

1;
