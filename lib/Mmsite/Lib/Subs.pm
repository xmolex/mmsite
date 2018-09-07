package Mmsite::Lib::Subs;
#########################################################################################################
# модуль общие функции широкого спектра
#########################################################################################################
use Modern::Perl;
use utf8;
use Encode;
use Fcntl qw(:DEFAULT :flock);
use Exporter 'import';

our @EXPORT = qw(
                   tr_sql
                   tr_html
                   get_sql_time
                   on_utf8
                   size_to_str
                   get_extension
                   convert_filename_to_latin
                   get_uniq_filename
                   is_running
                   to_log
);

# получаем SQL команду и экранируем опасности
sub tr_sql {
    my $str = shift;
    $str =~ s/'/''/gs;
    return $str;
}

# производим замены для принятых значений, которые должны пойти на вывод в html
sub tr_html {
    my $str = shift;
    $str =~ s/&/&amp;/gs;
    $str =~ s/</&lt;/gs;
    $str =~ s/>/&gt;/gs;
    $str =~ s/'/&apos;/gs;
    $str =~ s/"/&quot;/gs;
    return $str;
}

# формируем дату и время для базы данных, либо только дату (флаг вторым параметром)
# время можно передать в unix формате
sub get_sql_time {
    my $time = shift // time();
    my( $sec, $min, $hour, $mday, $mon, $year ) = localtime($time);
    $year = $year + 1900;
    $mon++;
    
    # добавляем ведущие нули
    $mon  = sprintf '%02d', $mon;
    $mday = sprintf '%02d', $mday;
    $hour = sprintf '%02d', $hour;
    $min  = sprintf '%02d', $min;
    $sec  = sprintf '%02d', $sec;
    
    if ($_[0]) {
        # запрос только на дату
        return "$year-$mon-$mday";
    }
    else {
        # запрос на дату и время
        return "$year-$mon-$mday $hour:$min:$sec";
    }
    
}

# функция выставляет флаг utf8 в on
# передаем ссылку на строку
sub on_utf8 {
    Encode::_utf8_on( ${ $_[0] } );
}

# получаем размер в байтах, а отдаем текстовую строку с удобным отображением
sub size_to_str {
    my $size = shift;

    # проверка на число
    return $size if $size !~ /^\d+$/;
    
    # высчитываем правильные значения
    if (! int($size / 1073741824) < 1 ) {
        # гигабайты
        $size = $size / 1073741824;
        return $size . '&nbsp;Gb'
                if $size - int($size) == 0;
        $size = sprintf '%0.2f', $size;
        return $size . '&nbsp;Gb';
    }
    
    elsif (! int($size / 1048576) < 1 ) {
        # мегабайты
        $size = $size / 1048576;
        return $size . '&nbsp;Mb'
                if $size - int($size) == 0;
        $size = sprintf '%0.2f', $size;
        return $size . '&nbsp;Mb';

    }
    
    elsif (! int($size / 1024) < 1 ) {
        # килобайты
        $size = $size / 1024;
        return $size . '&nbsp;Kb'
                if $size - int($size) == 0;
        $size = sprintf '%0.2f', $size;
        return $size . '&nbsp;Kb';
    }
    
    # байты
    return $size . '&nbsp;bytes';
}

# получаем имя или путь к файлу и отдаем расширение файла
sub get_extension {
    my $str = shift;
    
    my $extension;
    
    # если передали с unix путем, отделяем имя файла
    my $pos = rindex $str, '/';
    if ($pos != -1) {$str = substr($str, $pos + 1);}
    
    # если передали с win путем, отделяем имя файла
    $pos = rindex $str, '\\';
    if ($pos != -1) {$str = substr($str, $pos + 1);}
    
    # отделяем расширение
    $pos = rindex $str, '.';
    if ($pos != -1) {$extension = substr($str, $pos + 1);}
    
    return $extension;
}

# переводим имя файла в латиницу
sub convert_filename_to_latin {
  my $name = shift;
  on_utf8(\$name);

  # замещаем
  $name =~ s/а/a/g;   $name =~ s/А/a/g; 
  $name =~ s/б/b/g;   $name =~ s/Б/b/g;
  $name =~ s/в/v/g;   $name =~ s/В/v/g;
  $name =~ s/г/g/g;   $name =~ s/Г/g/g;
  $name =~ s/д/d/g;   $name =~ s/Д/d/g;
  $name =~ s/е/e/g;   $name =~ s/Е/e/g;
  $name =~ s/ё/jo/g;  $name =~ s/Ё/jo/g;
  $name =~ s/ж/zh/g;  $name =~ s/Ж/zh/g;
  $name =~ s/з/z/g;   $name =~ s/З/z/g;
  $name =~ s/и/i/g;   $name =~ s/И/i/g;
  $name =~ s/й/j/g;   $name =~ s/Й/j/g;
  $name =~ s/к/k/g;   $name =~ s/К/k/g;
  $name =~ s/л/l/g;   $name =~ s/Л/l/g;
  $name =~ s/м/m/g;   $name =~ s/М/m/g;
  $name =~ s/н/n/g;   $name =~ s/Н/n/g;
  $name =~ s/о/o/g;   $name =~ s/О/o/g;
  $name =~ s/п/p/g;   $name =~ s/П/p/g;
  $name =~ s/р/r/g;   $name =~ s/Р/r/g;
  $name =~ s/с/s/g;   $name =~ s/С/s/g;
  $name =~ s/т/t/g;   $name =~ s/Т/t/g;
  $name =~ s/у/u/g;   $name =~ s/У/u/g;
  $name =~ s/ф/f/g;   $name =~ s/Ф/f/g;
  $name =~ s/х/kh/g;  $name =~ s/Х/kh/g;
  $name =~ s/ц/c/g;   $name =~ s/Ц/c/g;
  $name =~ s/ч/ch/g;  $name =~ s/Ч/ch/g;
  $name =~ s/ш/sh/g;  $name =~ s/Ш/sh/g;
  $name =~ s/щ/shh/g; $name =~ s/Щ/shh/g;
  $name =~ s/ъ//g;    $name =~ s/Ъ//g;
  $name =~ s/ы/y/g;   $name =~ s/Ы/y/g;
  $name =~ s/ь//g;    $name =~ s/Ь//g;
  $name =~ s/э/eh/g;  $name =~ s/Э/eh/g;
  $name =~ s/ю/ju/g;  $name =~ s/Ю/ju/g;
  $name =~ s/я/ja/g;  $name =~ s/Я/ja/g;
  $name =~ s/\s/_/g;

  # собираем имя из безопасных символов
  $name = join "", grep { /[A-Za-z0-9\.\_\-]/i } split //, $name;
  
  return $name;
}

# функция формирования случайного имени для файла
sub get_uniq_filename {
   my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime();
   my $name = $sec + $min * 60 + $hour * 3600 + $mday * 86400 + $mon * 2678400 + $year * 977616000;
   $name .= int( rand(999) );
   return $name;
}

# функция проверки запуска копии скрипта
sub is_running {
    my $pidfile = shift;
    my $result;

    sysopen LOCK, $pidfile, O_RDWR|O_CREAT or die "Невозможно открыть файл $pidfile: $!";

    # пытаемся заблокировать файл
    if ( flock LOCK, LOCK_EX|LOCK_NB  ) {
        # блокировака удалась, поэтому запишем в файл наш идентификатор процесса
        truncate LOCK, 0 or warn "Невозможно усечь файл $pidfile: $!";
        my $old_fh = select LOCK;
        $| = 1;
        select $old_fh;
        print LOCK $$;
        # оставим файл открытым и заблокированным
    }
    else {
        # заблокировать не удалось, т.к. кто-то уже заблокировал файл
        $result = <LOCK>;

        # получим идентификатор процесса
        if (defined $result) {
            chomp $result;
        }
        else {
            warn "Отсутствует PID в пид-файле $pidfile";
            $result = 'block';
        }
    }

    return $result;
}

sub to_log {
    # реализации записи в лог файл
    # получаем путь к файлу, тип и строку лога
    my ( $path_file, $type, $str ) = @_;
    return if ( !$path_file || !$type || !$str );
    
    open my $fn, '>>:utf8', $path_file;
    return unless $fn;
    say $fn $type . ":\t" . get_sql_time() . "\t" . $str;
    close $fn;
}

1;

