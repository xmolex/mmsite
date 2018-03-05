################################################################################
# Модуль работы с базой данных
################################################################################
package Mmsite::Lib::Db;

use Modern::Perl;
use utf8;
use DBI;
use Mmsite::Lib::Vars;
use Exporter 'import';
our @EXPORT = qw(&sql);

my $conn;

# подключаемся к базе
sub _toconnect {
    $conn = DBI->connect("dbi:Pg:dbname=$DB_NAME;host=$DB_HOST;port=$DB_PORT;", "$DB_USER", "$DB_PASS", {AutoCommit => 1, PrintError => 1, RaiseError => 0});
    if ($conn) {
        $conn->{pg_enable_utf8} = 1;
        $conn->do("SET CLIENT_ENCODING TO 'UTF8';");
        return 1;
    }
    else {
        warn "Don't connect database: \'\"dbi:Pg:dbname=$DB_NAME;host=$DB_HOST;port=$DB_PORT;\", \"$DB_USER\", \"$DB_PASS\"'\n";
        return;
    }
}

# выполняем sql запрос
# вторым параметром передают флаг, когда не ожидают ответа
sub sql {
    my ( $command, $do ) = @_;
    my @result = ();
    
    # если команды нет, отдаем пустой массив
    return (\@result) unless $command;
  
    # если не подключены, то пробуем подключиться
    if (!$conn) {
        if ( ! _toconnect() ) {
            _to_log("Don't connect database server");
            $conn = 0;
            return \@result;
        }
    }
    
    if ($do) {
        # запрос на выполнение без ответа
        unless ( $conn->do("$command") ) {
            # ошибка выполнения
            my $err_msg = $conn->errstr();
            on_utf8(\$err_msg);
            my ( $package, $filename, $line ) = caller;
            _to_log("$package:$line | $err_msg: '$command'");
            return;
        } else {
            # выполнить удалось
            return 1;
        }
    }
    else {
        # запрос на выполнение с получением данных
        my $strin = $conn->prepare($command);
        if ($strin->execute) {
            # запрос выполнен
            while (my @value = $strin->fetchrow_array) {
                # заполняем массив данными для вывода
                push @result, $_ for (@value);
            }
            $strin->finish;
            return (\@result);
        } else {
            # ошибка выполнения
            my $err_msg = $conn->errstr();
            on_utf8(\$err_msg);
            my ( $package, $filename, $line ) = caller;
            _to_log("$package:$line | $err_msg: '$command'");
        }
    }
    return \@result;
}

sub _to_log {
    my ($str) = @_;
    open my $fn, '>>:utf8', $PATH_LOG_DB;
    return unless $fn;
    say $fn "| " . get_sql_time() . " | " . $str;
    close $fn;
}
1;
