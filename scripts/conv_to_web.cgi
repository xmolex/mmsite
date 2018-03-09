#!/usr/bin/perl
###################################################################################################################
# скрипт проходится по базе, находит не пережатые видео файлы и пытается их пережать в web формат, попутно
# создав изображение превьюшку и заполнив данные по видео
###################################################################################################################

use Modern::Perl;
use utf8;
use FindBin;
use lib "$FindBin::Bin/../lib";
use File::Copy;
use Mmsite::Lib::Vars;
use Mmsite::Lib::Db;
use Mmsite::Lib::Files;
use Mmsite::Lib::Groups;
$| = 1;
binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

###################################################################################
# НАСТРОЙКИ
###################################################################################
my $PID_FILE            = $PATH_TMP . 'conv_to_web.pid'; # путь к PID файлу для этого скрипта

# проверяем, не запущена ли копия программы
die "Script is already running...\n" if is_running($PID_FILE);
 
# основное тело программы
work();
 
sub work {
    if ($ARGV[0]) {
        # пережимаем какой-то конкретный файл
        # проверяем идентификатор файла
        my $file_id = $ARGV[0];
        if ($file_id !~ m/^\d+$/) {
            say "r1";
            return;
        }
        
        my $sql = sql("SELECT id,file FROM files WHERE id='$file_id';");
        
        if ( Mmsite::Lib::Ffmpeg::is_video_extension( get_extension $$sql[1] ) ) {
            my %parm;
            ConvFile($file_id,\%parm);
        } else {
            say "'$$sql[1]' not support format";
        }
    }
    else {
        # жмем последние
        my $sql = sql( qq|SELECT 
                               id,file 
                           FROM files 
                           WHERE 
                               (
                                 is_web IS NULL
                                 OR is_web = FALSE
                                 OR id IN (SELECT file_id FROM files_conv_setting WHERE status='1')
                               ) AND file_id = 0 
                           ORDER BY id DESC;
                   |);
        for ( my $i = 0; $i < @$sql; $i = $i + 2 ) {
            # проверяем на допустимые форматы
            unless ( Mmsite::Lib::Ffmpeg::is_video_extension( get_extension $$sql[$i+1] ) ) {
                say "File '$$sql[$i+1]' not support, skip";
                next;
            }
        
            # жмем
            ConvFile($$sql[$i]);
        }
    }
}

# кодируем файл (0 - неудача, 1 - удачно)
sub ConvFile {
    my $file_id = shift || return;
    
    my $file = Mmsite::Lib::Files->new($file_id);
    return unless $file;
    
    # получаем информацию об объекте
    $file->get();
    
    # пережимаем
    my ($result, $error) = $file->conv_to_web();
    
    unless ($result) {
        # не удалось пережать, выходим
        say $error;
        return;
    }
    
    # пережалось успешно, нужно очистить кеш объекта группы по файлам
    if ( $file->parent_id ) {
        my $obj_group = Mmsite::Lib::Groups->new( $file->parent_id );
        $obj_group->clear_cache_data_file() if $obj_group;
    }
    
    return 1;
}