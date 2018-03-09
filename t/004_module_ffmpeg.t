# ���� ������� ������ Mmsite::Lib::Ffmpeg
use Modern::Perl;
use utf8;
use lib "../lib";
use Mmsite::Lib::Ffmpeg;
use Test::More tests => 5;

# ������� is_video_extension
ok( Mmsite::Lib::Ffmpeg::is_video_extension("avi"), 'is_video_extension (short)' );
ok( Mmsite::Lib::Ffmpeg::is_video_extension("1.avi"), 'is_video_extension (long)' );

# ������� is_subtitle_extension
ok( Mmsite::Lib::Ffmpeg::is_subtitle_extension("vtt"), 'is_subtitle_extension (short)' );
ok( Mmsite::Lib::Ffmpeg::is_subtitle_extension("1.vtt"), 'is_subtitle_extension (long)' );

# ������� conv_sec_in_text
is( Mmsite::Lib::Ffmpeg::conv_sec_in_text('3601'), '01:00:01', 'conv_sec_in_text' );

done_testing();