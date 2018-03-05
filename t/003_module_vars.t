# тест функций модуля Lib::Vars
use Modern::Perl;
use utf8;
use FindBin;
use lib "$FindBin::../lib";
use Lib::Vars;
use Test::More tests => 15;

# функция tr_sql
is( tr_sql("'"), "''", 'tr_sql' );

# функция tr_html
is( tr_html("+&<>\n'\"+"), "+&amp;&lt;&gt;\n&apos;&quot;+", 'tr_html' );

# функция get_sql_time
is( get_sql_time( 1519915314, 1 ), '2018-03-01', 'get_sql_time (date)' );
is( get_sql_time( 1519915314 ), '2018-03-01 17:41:54', 'get_sql_time (date & time)' );

# функция size_to_str
is( size_to_str("q"), 'q', 'size_to_str (broken)' );
is( size_to_str(1024*1024*1024), '1&nbsp;Gb', 'size_to_str (Gb)' );
is( size_to_str(1.5*1024*1024*1024), '1.50&nbsp;Gb', 'size_to_str (Gb dec)' );
is( size_to_str(1024*1024), '1&nbsp;Mb', 'size_to_str (Mb)' );
is( size_to_str(1.5*1024*1024), '1.50&nbsp;Mb', 'size_to_str (Mb dec)' );
is( size_to_str(1024), '1&nbsp;Kb', 'size_to_str (Kb)' );
is( size_to_str(1.5*1024), '1.50&nbsp;Kb', 'size_to_str (Kb dec)' );
is( size_to_str(1), '1&nbsp;bytes', 'size_to_str (bytes)' );

# функция get_extention
is( get_extention('video.avi'), 'avi', 'get_extention (without path)' );
is( get_extention('/usr/local/image.jpeg'), 'jpeg', 'get_extention (with unix path)' );
is( get_extention('c:\usr\bin\perl.exe'), 'exe', 'get_extention (with win path)' );

done_testing();