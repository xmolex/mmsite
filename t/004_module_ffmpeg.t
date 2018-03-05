# тест функций модуля Lib::Ffmpeg
use Modern::Perl;
use utf8;
use FindBin;
use lib "$FindBin::../lib";
use Lib::Ffmpeg;
use Test::More tests => 5;

# функция is_video_extension
ok( Lib::Ffmpeg::is_video_extension("avi"), 'is_video_extension (short)' );
ok( Lib::Ffmpeg::is_video_extension("1.avi"), 'is_video_extension (long)' );

# функция is_subtitle_extension
ok( Lib::Ffmpeg::is_subtitle_extension("vtt"), 'is_subtitle_extension (short)' );
ok( Lib::Ffmpeg::is_subtitle_extension("1.vtt"), 'is_subtitle_extension (long)' );

# функция conv_sec_in_text
is( Lib::Ffmpeg::conv_sec_in_text('3601'), '01:00:01', 'conv_sec_in_text' );

done_testing();