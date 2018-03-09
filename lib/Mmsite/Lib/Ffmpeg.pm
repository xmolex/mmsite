################################################################################
# модуль получения информации от ffmpeg и ffprobe по мультимедиа файлу
################################################################################
package Mmsite::Lib::Ffmpeg;

#  new => объявляет объект
################################################################################
# настройки для ffmpeg (смотри man ffmpeg)
################################################################################
our $FFMPEG_PAR_ASYNC  = '1';
our $FFMPEG_PAR_AF     = '"volume=1.5"';
################################################################################

use Modern::Perl;
use utf8;
use JSON::XS;
use File::Copy;
use Mmsite::Lib::Vars;

# объявление объекта
sub new {
    my ( $class, $path ) = @_;
    
    # проверяем на существование файла
    return( 0, 'error: file not found') unless (-f $path);

    
    # делаем запрос на информацию по файлу от ffmpeg
    my $data = `$PATH_FFPROBE -v quiet -print_format json -show_streams -show_format $path`;
    on_utf8(\$data);
    
    # обрабатываем JSON
    my $json_data;
    my $json_xs = JSON::XS->new();
    unless (eval { $json_data = $json_xs->decode($data) } ) {
        return( 0, 'error: неверная структура JSON от ffprobe');
    }
    
    return( 0, 'error: не найдены дорожки в файле, этот файл не является мультимедиа') unless ( defined $$json_data{'streams'} );
    
    on_utf8(\$json_data);

    # объявляем
    my $self = { path => $path, info => $json_data };
    bless $self, $class;
}

# получаем информацию о мультимедиа файле 
sub get {
    my ($self) = @_;
    
    my $json_data = $self->{'info'};
    
    # определяем рабочие дорожки: видео
    unless ( defined $self->{'video_track'} ) {
        foreach my $el ( @{$$json_data{'streams'}} ) {
            if ( $$el{'codec_type'} eq 'video' && $$el{'codec_name'} ne 'mjpeg' ) {
                $self->{'video_track'} = $$el{'index'};
                last;
            }
        }
    }
    
    return( 0, 'error: не удалось определить видео дорожку' ) unless defined $self->{'video_track'};
    
    # определяем рабочие дорожки: аудио
    unless ( defined $self->{'audio_track'} ) {
        my $track = '';
    
        foreach my $el ( @{$$json_data{'streams'}} ) {
            if ( $$el{'codec_type'} eq 'audio' ) {
                my $tmp = $$el{'tags'};
            
                # если дорожка еще не выбрана, то выбираем самую первую
                unless ($track) {$track = $$el{'index'};}

                # если найдем лучше, то выберем ее
                if ( defined $$tmp{'language'} && defined $$el{'codec_name'} && defined $$el{'channels'} ) {
                    if ( $$tmp{'language'} eq 'rus' && $$el{'codec_name'} eq 'aac' && $$el{'channels'} == 2) {
                        # нашли идеальную
                        $self->{'audio_track'} = $$el{'index'};
                        last;
                    }
                }
                
                # если идеальную не найдем, то поищем русскую
                if ( defined $$tmp{'language'} ) {
                    if ( $$tmp{'language'} eq 'rus' ) {
                        $track = $$el{'index'};
                    }
                }
            }
        }
        
        if ($track ne '') {
            # нашли дорожку
            $self->{'audio_track'} = $track;
        }
    }
    
    return( 0, 'error: не удалось определить аудио дорожку' ) unless defined $self->{'audio_track'};
    
    # находим сопутствующую информацию по видео
    foreach my $el ( @{$$json_data{'streams'}} ) {
        if ( $$el{'index'} == $self->{'video_track'} ) {
            # нашли выбранную видео дорожку
            # видео: кодек
            if ( $$el{'codec_name'} ) {
                $self->{'video_codec'} = $$el{'codec_name'};
            }
            
            # видео: высоту и ширину
            if ( $$el{'width'} && $$el{'height'} ) {
                $self->{'video_width'}  = $$el{'width'};
                $self->{'video_height'} = $$el{'height'};
            }
            
            # видео: битрейт (Kb)
            if ( $$el{'bit_rate'} ) {
                $self->{'video_bitrate'} = int( $$el{'bit_rate'} / 1024 );
            }
            
            # продолжительность (sec)
            if ( $$el{'duration'} ) {
                $self->{'video_duration'} = int $$el{'duration'};
            }

            last;
        }
    }
    my $tmp = $$json_data{'format'};
    # если не нашли битрейт, то нужно поискать в выводе информации о формате
    unless ( defined $self->{'video_bitrate'}) {
        if ($$tmp{'bit_rate'}) {
            $self->{'video_bitrate'} = int( $$tmp{'bit_rate'} / 1024 );
        }
    }
    # если не нашли продолжительность, то нужно поискать в выводе информации о формате
    unless ( defined $self->{'video_duration'}) {
        if ($$tmp{'duration'}) {
            $self->{'video_duration'} = int $$tmp{'duration'};
        }
    }
    
    # проверяем на результат
    return( 0, 'error: не удалось определить кодек видео' )             unless defined $self->{'video_codec'};
    return( 0, 'error: не удалось определить битрейт видео' )           unless defined $self->{'video_bitrate'};
    return( 0, 'error: не удалось определить разрешение видео' )        unless ( defined $self->{'video_width'} && defined $self->{'video_height'} );
    return( 0, 'error: не удалось определить продолжительность видео' ) unless defined $self->{'video_duration'};
    
    # находим сопутствующую информацию по аудио
    foreach my $el ( @{$$json_data{'streams'}} ) {
        if ( $$el{'index'} == $self->{'audio_track'} ) {
            # нашли выбранную аудио дорожку
            # аудио: кодек
            if ( $$el{'codec_name'} ) {
                $self->{'audio_codec'} = $$el{'codec_name'};
            }
            
            # аудио: количество каналов
            if ( $$el{'channels'} ) { 
                $self->{'audio_channels'} = $$el{'channels'};
            }
            last;
        }
    }
    # проверяем на результат
    return( 0, 'error: не удалось определить кодек аудио' ) unless defined $self->{'audio_codec'};
}

# устанавливаем свойства, без какой-либо внешней модификации 
sub set {
    my ( $self, $key, $value ) = @_;
    return unless $key;
    $self->{$key} = $value;
    return 1;
}

# расчитываем разрешение и битрейт для кодирования видео
sub get_convert_resbit {
    my ($self) = @_;
    
    # получаем данные
    my ( $result, $error ) = $self->get();
    return( 0, 'error: не удалось, т.к. не получены исходные данные' ) unless $result;
    
    # если дошли, то все данные получены и можно расчитывать

    # объявляем ширину и высоту для кодирования
    $self->{'video_conv_width'}  = $self->{'video_width'};
    $self->{'video_conv_height'} = $self->{'video_height'};
    
    # проверяем на допустимую высоту
    if ( $self->{'video_height'} > $VIDEO_MAX_HEIGHT ) {
        $self->{'video_conv_width'} = int( $self->{'video_width'} * $VIDEO_MAX_HEIGHT / $self->{'video_height'} );
        $self->{'video_conv_height'} = $VIDEO_MAX_HEIGHT;
    }
    
    # проверяем на допустимую ширину
    if ( $self->{'video_width'} > $VIDEO_MAX_WIDTH ) {
        $self->{'video_conv_height'} = int( $self->{'video_height'} * $VIDEO_MAX_WIDTH / $self->{'video_width'} );
        $self->{'video_conv_width'} = $VIDEO_MAX_WIDTH;
    }
    
    # ffmpeg требует четной высоты и ширины
    $self->{'video_conv_height'}++ if ( $self->{'video_conv_height'} % 2 != 0 );
    $self->{'video_conv_width'}++  if ( $self->{'video_conv_width'}  % 2 != 0 );

    # расчитываем битрейт видео
    if ( $self->{'video_conv_width'} == $self->{'video_width'} && $self->{'video_conv_height'} == $self->{'video_height'} ) {
        # битрейт для сжатия равен оригинальному
        $self->{'video_conv_bitrate'} = $self->{'video_bitrate'};
        
        # максимальный битрейт ограничен настройками
        $self->{'video_conv_bitrate'} = $VIDEO_MAX_BITRATE if $self->{'video_conv_bitrate'} > $VIDEO_MAX_BITRATE;
    }
    else {
        # высчитываем на сколько количество пикселей оригинального видео больше, чем будет в результате
        my $coof = ( $self->{'video_width'} * $self->{'video_height'} ) / ( $self->{'video_conv_width'} * $self->{'video_conv_height'} );
        
        # рассчитываем битрейт
        $self->{'video_conv_bitrate'} = int( $self->{'video_bitrate'} / $coof );
        
        # максимальный битрейт ограничен настройками
        $self->{'video_conv_bitrate'} = $VIDEO_MAX_BITRATE if $self->{'video_conv_bitrate'} > $VIDEO_MAX_BITRATE;
    }
    
    return 1;    
}


# метод конвертации видео в web формат
# возвращаем ложь или истину, а также путь к пережатому файлу и файлу превью
sub conv {
    my ( $self, $obj_files, $force ) = @_;
    
    # получаем данные
    my ( $result, $error ) = $self->get();
    return( 0, 'error: не удалось, т.к. не получены исходные данные' ) unless $result;
    
    ( $result, $error ) = $self->get_convert_resbit();
    return( 0, 'error: не удалось, т.к. не удалось расчитать данные для кодирования' ) unless $result;
    
    # получаем пользовательские настройки для сжатия из пакета который запросил нас
    $obj_files->get_conv_setting();
    
    # если статус пустой, значит запрос на сжатие впервые
    # ложь - данные не указаны, 1 - ожидает кодирования, 2 - выполнено, 3 - в процессе кодирования
    $obj_files->set_conv( 'conv_status', 0 ) unless defined $obj_files->conv_status;
    
    # объявляем используемые переменные
    my $video_target_name             = $PATH_TMP . int( rand(999999999999) );
    my $video_target_name_with_prefix = $video_target_name . '_';
    my $image_target_name             = $PATH_TMP . int( rand(999999999999) );
    
    # проверяем, а нужно ли пережимать
    my $need_conv = 1;
    
    unless ($force) {
        # определяем видео и аудио кодек файла
        if ( $self->{'video_codec'} eq 'h264' 
                && $self->{'audio_codec'} eq 'aac' 
                && $self->{'audio_channels'} == 2 
                && $self->{'video_height'} <= $VIDEO_MAX_HEIGHT
                && get_extension( $self->{'path'} ) ne 'flv' # очень часто бывает рассинхрон звука и видео при простом копировании дорожек
           ) {
           # web поддерживает эти кодеки и условия, пережимать не нужно
           $need_conv = 0;
        }
    }

    if ($need_conv) {
        # нужно пережать
        
        # однако есть ситуация, когда нам не передали параметров, а видео уже требуемого формата, тогда его достаточно скопировать
        my $video_copy = 0;
        if ( !$obj_files->conv_status 
                && $self->{'video_codec'}   eq 'h264' 
                && $self->{'video_height'}  <= $VIDEO_MAX_HEIGHT 
                && $self->{'video_width'}   <= $VIDEO_MAX_WIDTH
                && $self->{'video_bitrate'} <= $VIDEO_MAX_BITRATE ) {
            $video_copy = 1;
        }
        
        # также есть ситуация, когда настройки исходного видео полностью равны настройкам для пережатия, поэтому можно также его скопировать
        if (    $self->{'video_codec'}      eq 'h264' 
                && $self->{'video_bitrate'} == $self->{'video_conv_bitrate'} 
                && $self->{'video_width'}   == $self->{'video_conv_width'} 
                && $self->{'video_height'}  == $self->{'video_conv_height'} ) {
            $video_copy = 1;
        }
        
        # объявляем значения для параметров по умолчанию
        $obj_files->set_conv( 'conv_set_b', $self->{'video_conv_bitrate'} )                                     unless $obj_files->conv_set_b;
        $obj_files->set_conv( 'conv_set_map', $self->{'audio_track'} )                                          unless $obj_files->conv_set_map;
        $obj_files->set_conv( 'conv_set_async', $FFMPEG_PAR_ASYNC )                                             unless $obj_files->conv_set_async;
        $obj_files->set_conv( 'conv_set_af', $FFMPEG_PAR_AF )                                                   unless $obj_files->conv_set_af;
        $obj_files->set_conv( 'conv_set_s', $self->{'video_conv_width'} . 'x' . $self->{'video_conv_height'} ) unless $obj_files->conv_set_s;
  
        # собираем параметры
        my $ptext = '-map 0:' . $self->{'video_track'};
        $ptext .= ' -map 0:' . $obj_files->conv_set_map;
        
        unless ($video_copy) {
            # если видео дорожку нужно пережимать
            $ptext .= ' -s '   . $obj_files->conv_set_s;
            $ptext .= ' -b:v ' . $obj_files->conv_set_b . "K";
            $ptext .= ' -ss '  . $obj_files->conv_set_ss if $obj_files->conv_set_ss;
            $ptext .= ' -t '   . $obj_files->conv_set_t  if $obj_files->conv_set_t;
        }
        else {
            # видео дорожку нужно просто скопировать
            $ptext .= ' -vcodec copy';
        }

        $ptext .= ' -async ' . $obj_files->conv_set_async;
        $ptext .= ' -af ' . $obj_files->conv_set_af;
        $ptext .= ' -ac 2 -f mp4 -y';
        
        # записываем настройки кодирования для этого файла
        $obj_files->set_conv( 'conv_change_time', time() );
        $obj_files->set_conv( 'conv_status', 3 ); # в процессе кодирования
        ( $result, $error ) = $obj_files->set_conv_setting();
        
        unless ($video_copy) {
            # пережимаем в два прохода
            _to_log("cd $PATH_TMP; $PATH_FFMPEG -i $self->{'path'} -pass 1 $ptext /dev/null"); # лог
            system("cd $PATH_TMP; $PATH_FFMPEG -i $self->{'path'} -pass 1 $ptext /dev/null");
            sleep(2); # для возможности отменить вручную
            
            _to_log("cd $PATH_TMP; $PATH_FFMPEG -i $self->{'path'} -pass 2 $ptext $video_target_name_with_prefix"); # лог
            system("cd $PATH_TMP; $PATH_FFMPEG -i $self->{'path'} -pass 2 $ptext $video_target_name_with_prefix");
            sleep(2); # для возможности отменить вручную
        }
        else {
            # пережимаем за один проход
            _to_log("cd $PATH_TMP; $PATH_FFMPEG -i $self->{'path'} $ptext $video_target_name_with_prefix"); # лог
            system("cd $PATH_TMP; $PATH_FFMPEG -i $self->{'path'} $ptext $video_target_name_with_prefix");
            sleep(2); # для возможности отменить вручную
        }
        
        # записываем настройки кодирования для этого файла
        $obj_files->set_conv( 'conv_change_time', time() );
        $obj_files->set_conv( 'conv_status', 2 ); # кодирование выполнено
        ( $result, $error ) = $obj_files->set_conv_setting();
        
        return( 0, 'fail convert video ' . $self->{'path'} ) unless ( -f $video_target_name_with_prefix );

    }
    else {
        # пережимать не потребовалось
        # однако файл может быть запакован в неподдерживаемый контейнер, к примеру, flv, тогда нужно перепаковать
        if ($self->{'path'} !~ m!\.mp4$!i) {
            # перепаковываем
            _to_log("cd $PATH_TMP; $PATH_FFMPEG -i $self->{'path'} -map 0:0 -map 0:1 -vcodec copy -acodec copy -async 1 -f mp4 -y $video_target_name_with_prefix"); # лог
            system("cd $PATH_TMP; $PATH_FFMPEG -i $self->{'path'} -map 0:0 -map 0:1  -vcodec copy -acodec copy -async 1 -f mp4 -y $video_target_name_with_prefix");
            sleep(2); # для возможности отменить вручную
            return( 0, 'fail convert video to mp4 ' . $self->{'path'} ) unless ( -f $video_target_name_with_prefix );
        }
        else {
            # просто копируем файл для дальнейшей работы
            copy($self->{'path'}, $video_target_name_with_prefix);
        }
        
    }

    # переносим техническую информацию в начало файла для перемотки в плеере до полной загрузки
    _to_log("cd $PATH_TMP; $PATH_QTFASTSTART $video_target_name_with_prefix $video_target_name"); # лог
    system("cd $PATH_TMP; $PATH_QTFASTSTART $video_target_name_with_prefix $video_target_name");
    sleep(2); # для возможности отменить вручную
    
    if (! -f $video_target_name) {
        # по каким-то причинам, QTFASTSTART не смог перенести информацию. продолжим без него
        move($video_target_name_with_prefix, $video_target_name);
    }
    else {
        # удаляем временный файл
        unlink $video_target_name_with_prefix;
    }
  
    # определяем середину в продолжительности, чтобы сделать кадр-превью
    my $duration_half_sec = int( $self->{'video_duration'} / 2 );
    my $duration_half_text = conv_sec_in_text($duration_half_sec);
  
    # делаем кадр-превью
    _to_log("cd $PATH_TMP; $PATH_FFMPEG -y -ss $duration_half_text -i $video_target_name -an -r 1 -vframes 1 -f mjpeg $image_target_name"); # лог
    system("cd $PATH_TMP; $PATH_FFMPEG -y -ss $duration_half_text -i $video_target_name -an -r 1 -vframes 1 -f mjpeg $image_target_name");
    sleep(2); # для возможности отменить вручную
    if (!-f $image_target_name) {
        unlink $video_target_name;
        return( 0, 'fail create image preview' );
    }
    
    # возвращаем результат
    return( 1, $video_target_name, $image_target_name );
}

# копируем субтитры из видеофайла в отдельные файлы
sub clone_subtitles {
    my ($self) = @_;

    # получаем информацию о дорожках с субтитрами
    my $subtitles = $self->get_subtitle_track();
    
    # проходимся по всем дорожкам и извлекаем субтитры
    my @result;
    my $rand = int(999999);
    foreach my $map ( sort keys %$subtitles ) {
    
        # формируем путь к временному файлу субтитров
        $rand++;
        my $name_tmp_subtitle = $rand . '.vtt';
        my $path_tmp_subtitle = $PATH_TMP . $name_tmp_subtitle;
        
        # извлечение
        _to_log("cd $PATH_TMP; $PATH_FFMPEG -i $self->{'path'} -map 0:$map -an -vn -c:s:0 webvtt $path_tmp_subtitle"); # лог
        system("cd $PATH_TMP; $PATH_FFMPEG -i $self->{'path'} -map 0:$map -an -vn -c:s:0 webvtt $path_tmp_subtitle");
        sleep(2); # для возможности отменить вручную
        
        # проверка на успешность
        if (-f $path_tmp_subtitle) {
            # извлечение прошло успешно
            
            # проверяем на размер
            my @stat = stat($path_tmp_subtitle);
            if ($stat[7] == 0) {
                # извлечение прошло с ошибками, избавляемся от файла
                unlink $path_tmp_subtitle;
                next;
            }
            
            # добавляем файл в структуру
            # формируем название файла
            my $title = '';
            if ( $$subtitles{$map}{'language'} ) {$title .= '_' . $$subtitles{$map}{'language'};}
            if ( $$subtitles{$map}{'title'} )    {$title .= '_' . $$subtitles{$map}{'title'};}
            if ($title) {$title .= '_sub';}
            
            # формируем структуру для создания файла
            my $hash = {
                           'title' => $title,
                           'path'  => $path_tmp_subtitle,
                           'name'  => $name_tmp_subtitle,
            };
            
            push @result, $hash;
        }
    }
    
    return(\@result);
}

# создаем из видео файла указанное количество скриншотов через равные интервалы и возвращаем массив с путями к этим скриншотам
sub create_shots {
    my ( $self, $count ) = @_;
    
    my @result;
    
    # проверяем количество
    return \@result unless $count;
    return \@result if $count !~ m/^\d+$/;
    
    # проверка на существование видео дорожки
    return \@result unless defined $self->{'video_track'};
    
    # проверка на продолжительность видео в секундах
    return \@result unless $self->{'video_duration'};
    
    # определяем интервал между кадрами в секундах
    # количество увеличено на 2, чтобы исключить начало и конец файла
    my $interval = int( $self->{'video_duration'} / ( $count + 2 ) );
    
    # делаем кадры
    foreach my $c ( 0 .. $count ) {
        # получаем время в которое нужно сделать кадр
        my $sec      = ( $c + 1 ) * $interval;
        my $sec_text = conv_sec_in_text($sec);
                
        # определяемся с путем к новому кадру
        my $name_img = time() . int( rand(10) ) . '.jpg';
        my $path_img = $PATH_TMP . $name_img;
                
        # делаем кадр с помощью ffmpeg
        _to_log("cd $PATH_TMP; $PATH_FFMPEG -y -ss $sec_text -i $self->{'path'} -an -r 1 -vframes 1 -f mjpeg $path_img"); # лог
        system("cd $PATH_TMP; $PATH_FFMPEG -y -ss $sec_text -i $self->{'path'} -an -r 1 -vframes 1 -f mjpeg $path_img");
                
        if (-f $path_img) {
            # файл с кадром создался
            push @result, $path_img;
        }
    }
    
    # возвращаем результат
    return \@result;
}


# отдаем массив аудиодорожек
sub get_audio_track {
    my ($self) = @_;
    
    # для вывода
    my %audio;
    
    # проходимся по всем дорожкам и ищем тип кодека audio
    my $json_data = $self->{'info'};
    foreach my $el ( @{$$json_data{'streams'}} ) {
        if ( $$el{'codec_type'} eq 'audio' ) {
            my $map = $$el{'index'};
            my $tmp = $$el{'tags'};
            $audio{$map}{'title'}      = $$tmp{'title'};
            $audio{$map}{'language'}   = $$tmp{'language'};
            $audio{$map}{'codec_name'} = $$el{'codec_name'};
            $audio{$map}{'channels'}   = $$el{'channels'};
        }
    }
    
    # отдаем
    return \%audio;
}

# отдаем массив дорожек субтитров
sub get_subtitle_track {
    my ($self) = @_;
    
    # для вывода
    my %subtitles;

    # проходимся по всем дорожкам и ищем тип кодека audio
    my $json_data = $self->{'info'};
    foreach my $el ( @{$$json_data{'streams'}} ) {
        if ( $$el{'codec_type'} eq 'subtitle' ) {
            my $map = $$el{'index'};
            my $tmp = $$el{'tags'};
            $subtitles{$map}{'title'}    = $$tmp{'title'};
            $subtitles{$map}{'language'} = $$tmp{'language'};
        }
    }
    
    # отдаем
    return \%subtitles;
}

# следующие функции являются просто функциями и работают без объекта
# отдаем истину, если это расширение относится к видео файлу
sub is_video_extension {
    my ($extension) = @_;
    
    # проверяем на присланное значение    
    my $pos = rindex( $extension, '.' );
    $extension = substr( $extension, $pos + 1 ) if ($pos != -1); # если отправили не расширение, а имя файла, отделяем расширение
    
    # проверяем на тип
    return 1 if $extension =~ m/^avi|mp4|mkv|mov|flv|mpg|m4v|m2ts$/i;
    return;
}

# отдаем истину, если это расширение относится к субтитрам
sub is_subtitle_extension {
    my ( $extension ) = @_;

    # проверяем на присланное значение    
    my $pos = rindex( $extension, '.' );
    $extension = substr( $extension, $pos + 1 ) if ($pos != -1); # если отправили не расширение, а имя файла, отделяем расширение
    
    # проверяем на тип
    return 1 if $extension =~ m/^srt|ass|vtt$/i;
    return;
}

# получаем число секунд продолжительности видео и отдаем в формате ЧЧ:ММ:СС
sub conv_sec_in_text {
    my $sec = $_[0] || return "00:00:00";
    my ($hour,$min);
    
    # часы
    if ($sec / 3600 > 0) {
        $hour = int($sec / 3600);
        $sec = $sec % 3600;
    }
    else {
        $hour = "00";
    }
    
    # минуты
    if ($sec / 60 > 0) {
        $min = int($sec / 60);
        $sec = $sec % 60;
    }
    else {
        $min = "00";
    }
    
    # добавляем ведущие нули
    $hour = sprintf '%02d', $hour;
    $min  = sprintf '%02d', $min;
    $sec  = sprintf '%02d', $sec;
    
    return "$hour:$min:$sec";
}


# аксессоры
sub path           { return shift->{path}; }
sub info           { return shift->{info}; }
sub video_track    { return shift->{video_track}; }
sub audio_track    { return shift->{audio_track}; }
sub video_codec    { return shift->{video_codec}; }
sub video_width    { return shift->{video_width}; }
sub video_height   { return shift->{video_height}; }
sub video_bitrate  { return shift->{video_bitrate}; }
sub video_duration { return shift->{video_duration}; }
sub audio_codec    { return shift->{audio_codec}; }
sub audio_channels { return shift->{audio_channels}; }


# локальные функции
# получаем строку лога и записываем в файл
sub _to_log {
    my $text = $_[0] || return;
    
    # получаем время
    my $time = get_sql_time();
    
    # получаем инициатора
    my ( $package, $filename, $line ) = caller;
    
    # открываем файл и записываем
    open my $fn, ">>:utf8", $PATH_LOG_FFMPEG;
    return unless $fn;
    say $fn $time . "\t" . "$package:$line" . "\t" . $text;
    close $fn;
}

1;