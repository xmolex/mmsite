#!/usr/bin/perl
###################################################################################################################
# скрипт получает данные о видео и выводит их на экран
###################################################################################################################

use Modern::Perl;
use utf8;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Mmsite::Lib::Ffmpeg;
$| = 1;
binmode STDOUT, ':utf8';

# основное тело программы
work();
  
sub work {
    # проверяем наличие файла
    unless ($ARGV[0]) {
        print "path file is null\n";
        return;
    }
        
    # получаем инфо
    my $ffmpeg = Mmsite::Lib::Ffmpeg->new($ARGV[0]);
    unless ($ffmpeg) {
        print "don't init ffmpeg\n";
        return;
    }
    
    my ( $result, $error ) = $ffmpeg->get();
    unless ($result) {
        print "$error\n";
        return;
    }
    
    
    # получаем разрешение рассчитанное для сжатия и оригинальное
    unless ( $ffmpeg->get_convert_resbit() ) {
        print "error: не удалось расчитать данные для кодирования";
        return;
    }
        
    # получаем продолжительность видео
    my $duration_text = Mmsite::Lib::Ffmpeg::conv_sec_in_text($ffmpeg->video_duration);

    # получаем список дорожек аудио и субтитров    
    my $audio     = $ffmpeg->get_audio_track();
    my $subtitles = $ffmpeg->get_subtitle_track();
    
    # выводим на экран 
    print "Map\n";
    print "  Video => '$ffmpeg->video_track'\n";
    print "  Audio => '$ffmpeg->audio_track'\n";
    
    print "Codec\n";
    print "  Video => '$ffmpeg->video_codec'\n";
    print "  Audio => '$ffmpeg->audio_codec' ($ffmpeg->audio_channels channels)\n";
        
    print "Bitrate\n";
    print "  Original => '$ffmpeg->video_bitrate'\n";
    print "  Target   => '$ffmpeg->video_conv_bitrate'\n";
    
    print "Duration => '$duration_text' or '$ffmpeg->video_duration' sec\n";
        
    print "Resolution\n";
    print "  Original => '$ffmpeg->video_width x $ffmpeg->video_height'\n";
    print "  Target   => '$ffmpeg->video_conv_width x $ffmpeg->video_conv_height'\n";
    
    print "Audio list\n";
    foreach my $key ( sort {$a <=> $b} keys %$audio ) {
        print "  $key ";
        if ( $$audio{$key}{'title'} ) {print "title=>'$$audio{$key}{'title'}' ";}
        if ( $$audio{$key}{'language'} ) {print "language=>'$$audio{$key}{'language'}' ";}
        print "\n";
    }
    
    print "Subtitles list\n";
    foreach my $key ( sort {$a <=> $b} keys %$subtitles ) {
        print "  $key ";
        if ( $$subtitles{$key}{'title'} ) {print "title=>'$$subtitles{$key}{'title'}' ";}
        if ( $$subtitles{$key}{'language'} ) {print "language=>'$$subtitles{$key}{'language'}' ";}
        print "\n";
    }
    
    
    
}