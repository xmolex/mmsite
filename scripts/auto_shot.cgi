#!/usr/bin/perl
###################################################################################################################
# скрипт создает изображения случайных кадров указанного видео или серии видео
###################################################################################################################
use Modern::Perl;
use utf8;
use FindBin;
use lib "$FindBin::Bin/../lib";
use File::Copy;
use Mmsite::Lib::Vars;
use Mmsite::Lib::Subs;
use Mmsite::Lib::Db;
use Mmsite::Lib::Ffmpeg;
use Mmsite::Lib::Groups;
use Mmsite::Lib::Images;
$| = 1;
binmode STDOUT, ':utf8';

work();

sub work {
    # получаем идентификатор
    my $group_id = $ARGV[0];
    unless ($group_id) {
        say "Use ./auto_shot.cgi object_id";
        return;
    }
    
    # проверяем его
    if ($group_id !~ m/^\d+$/) {
        say "error: wrong id";
        return;
    }
    my $group = Mmsite::Lib::Groups->new($group_id);
    unless ($group) {
        say "error: group object not found";
        return;
    }
    my @shots = $group->get_images('shots');
    if ($shots[0]) {
        say "error: shots already exists";
        return;
    }
    
    # получаем массив файлов для обработки и нарезки из них кадров
    my @files = $group->get_files('view');
    
    # проходимся по массиву и если файл не видео, то помечаем его идентификатор 0, заодно считая сколько файлов мы можем обработать
    my $video_file_count = 0;
    for (my $i = 0; $i < scalar(@files); $i = $i + 13) {

        if ( Mmsite::Lib::Ffmpeg::is_video_extension( get_extension $files[$i+2] ) ) {
            # файл с подходящим разрешением
            $video_file_count++;
        }
        else {
            # файл не подходит
            $files[$i] = 0;
        }
    }
    
    # определяемся, сколько кадров мы должны сделать в одном видео
    my $count_in_one_video = $MAX_AUTO_SHOTS / $video_file_count;
    if ( $count_in_one_video != int($count_in_one_video) ) {
        # если получилось не целое число, по делаем его целым, округляя в большую сторону
        $count_in_one_video = int( $count_in_one_video + 1 );
    }
    
    my @count_conv; # храним имена уже сделанных кадров
    # проходимся по видео файлам и нарезаем кадры
    for (my $i = 0; $i < scalar(@files); $i = $i + 13) {
        # проверяем, на количество уже сделанных кадров
        last if scalar(@count_conv) >= $MAX_AUTO_SHOTS;
    
        # если это видео файл, обрабатываем его
        if ($files[$i]) {
        
            # инициализируем видео в ffmpeg
            my $video = Mmsite::Lib::Ffmpeg->new("$PATH_FILES/$files[$i+2]");
            next unless $video; # не удалось, пропускаем

            $video->get();
            
            # проверяем не нужно ли изменить $count_in_one_video, т.к. сумма сделанных кадров может быть больше, чем $MAX_AUTO_SHOTS
            if ( scalar(@count_conv) + $count_in_one_video > $MAX_AUTO_SHOTS ) {
                $count_in_one_video = $MAX_AUTO_SHOTS - scalar(@count_conv);
            }

            my $result = $video->create_shots($count_in_one_video);
            foreach (@$result) {
                
                if (-f $_) {
                    # файл с кадром создался
                    
                    # придумываем для него имя
                    my $name = time() . int( rand(10) ) . '.jpg';
                    
                    # теперь преобразуем его в требуемое разрешение и добавим
                    my %hash = (
                                   type        => 3,
                                   source_name => $name,
                                   source_path => $_,
                                   parent_id   => $group_id,
                                   title       => scalar(@count_conv) + 1
                    );
                    
                    my $image = Mmsite::Lib::Images->create(\%hash);
                    if ($image) {
                        # удалось переконвертировать и привязать
                        # указываем, что файл добавился
                        push @count_conv, $_;
                        
                        # удаляем временный файл
                        unlink($_);
                    }
                }
                
                
            }
        }
    }
    
    # чистим кеши у объекта группы
    $group->clear_cache_data_image();
}
