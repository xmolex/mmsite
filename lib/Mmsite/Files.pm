package Mmsite::Files;
######################################################################################
# вывод информации о файлах объекта группы
######################################################################################
use Dancer2 appname => 'Mmsite';
use Modern::Perl;
use utf8;
use Mmsite::Lib::Vars;
use Mmsite::Lib::Subs;
use Mmsite::Lib::Files;
use Mmsite::Lib::Members;

prefix '/files';

# выводим информацию о группе
any '/:group_id' => sub {

    my $group_id = route_parameters->get('group_id');
    redirect '/' if $group_id !~ m/^\d+$/; 
   
    my $obj = Mmsite::Lib::Groups->new($group_id);
    redirect '/' if !$obj;
    
    # получаем информацию о текущем пользователе
    my $member_obj = Mmsite::Lib::Members->new();
   
    # получаем информацию об объекте группы
    $obj->get();
    
    my $player        = 0;  # нужно ли выводить плеер
    my $player_width  = 0;  # высота плеера
    my $player_height = 0;  # ширина плеера
    my @playlist      = (); # структура плейлиста
    
    # файлы
    my @files;
    my @views;
    # запрашиваем файлы данного объекта, вместе с информацией о них
    my @files_mass = $obj->get_files('view'); # [ id, title, file, size, res_x, res_y, is_web, count_download, count_view, translate, description, duration, dependent ]
    
    if ($files_mass[0]) {
        my $count = 0;
    
        # заносим в правильную структуру
        for ( my $i=0; $i<scalar(@files_mass); $i=$i+13 ) {
        
            # указываем перевод, если он есть
            if ($files_mass[$i+9]) {$files_mass[$i+9] = $LIST_TRANSLATE{$files_mass[$i+9]};}
            
            # создаем структуру для Text::Xslate
            my $data = {
                          is_web      => $files_mass[$i+6],
                          id          => $files_mass[$i],
                          title       => $files_mass[$i+1],
                          url         => $URL_FILES . $files_mass[$i+2],
                          size        => size_to_str($files_mass[$i+3]),
                          download    => $files_mass[$i+7],
                          view        => $files_mass[$i+8],
                          translate   => $files_mass[$i+9],
                          description => $files_mass[$i+10],
                          num         => $count
            };
            
            # увеличиваем порядковый номер, если это файл пережат под веб, для порядкового номера в плеере
            if ($files_mass[$i+6]) {$count++;}
            
            
            # если есть зависимые файлы, то их также необходимо добавить
            # попутно не забываем о субтитрах (тип файла: 2)
            my @depends   = ();
            my @subtitles = ();
                
            # если есть зависимые файлы
            if ( ref $files_mass[$i+12] eq 'ARRAY' && scalar( @{$files_mass[$i+12]} ) ) {
                # проходимся по каждому файлу и собираем информацию о нем
                foreach my $depend_id (@{$files_mass[$i+12]}) {
                    my $depend = Mmsite::Lib::Files->new($depend_id);
                    if ($depend) {
                        $depend->get();
                        my $depend_data = {
                                            url   => $URL_FILES . $depend->file,
                                            title => $depend->title,
                                            size  => size_to_str($depend->size)
                        };
                        push @depends, $depend_data; 
                            
                        # проверяем на субтитры
                        if ($depend->type == 2) { 
                            # это субтитры, добавляем для вывода
                            my $subtitle_data = {
                                                    file => $URL_FILES . $depend->file,
                                                    label => $depend->title
                            };
                            push @subtitles, $subtitle_data;
                        }
                    }
                }
                    
                # заносим информацию в структуру для Text::Xslate
                $$data{'depends'} = \@depends;
            }

            # собираем массив с информацией обо всех файлах    
            push @files, $data;
            
            # если файл является пережатым для просмотра, отмечаем, что нужен плеер с заданной шириной/высотой
            if ($files_mass[$i+6]) {
                $player = 1;
                
                # если данный файл уже просматривали, указываем это
                if ( $member_obj->is_view($files_mass[$i]) ) {
                    push @views, $files_mass[$i];
                }
                
                if ($player_width  < $files_mass[$i+4] + $PLAYER_PLAYLIST_WIDTH) {$player_width  = $files_mass[$i+4] + $PLAYER_PLAYLIST_WIDTH;} # приплюсовываем $PLAYER_PLAYLIST_WIDTH, т.к. размер плейлиста тоже считается
                if ($player_height < $files_mass[$i+5]) {$player_height = $files_mass[$i+5];}
                
                # добавляем в структуру плейлиста информацию о видео
                my $video_data = {
                                    file        => $URL_FILES . $files_mass[$i+2],
                                    image       => $URL_FILES_IMG . $files_mass[$i] . '.jpg',
                                    title       => $files_mass[$i+1],
                                    description => $files_mass[$i+11],
                                    id          => $files_mass[$i]
                };

                # если есть субтитры к файлу, то добавляем их
                if (scalar(@subtitles) > 0) {
                    $$video_data{'captions'} = \@subtitles;
                }
                
                push @playlist, $video_data;
            }
        }
    }
 
    # переводим плейлист в json для jwplayer
    my $playlist = to_json \@playlist;
    
    # перевернем список файлов, чтобы сначала были новые серии
    @files = reverse @files;
    
    # формируем массив js для просмотренных файлов
    my $views = join ",", @views;
 
    # выводим
    template 'group_files' => {
                                id          => $group_id,
                                title       => $obj->title,
                                year        => $obj->year,
                                files       => \@files,
                                user_id     => $member_obj->id,
                                videoaspect => 0,
                                videoheight => $player_height,
                                videowidth  => $player_width,
                                videolist   => $playlist,
                                player      => $player,
                                views       => $views,
                                player_playlist_width => $PLAYER_PLAYLIST_WIDTH # ширина плейлиста в видеоплеере
                             };
                             
};

1;
