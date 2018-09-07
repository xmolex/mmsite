package Mmsite::Lib::Mem;
################################################################################
# Модуль использования memcached
################################################################################
# настройки
################################################################################
my $MEM_SERVER = '127.0.0.1'; # memcached сервер
my $MEM_PORT   = '11211';     # memcached порт
################################################################################
use Modern::Perl;
use utf8;
use Cache::Memcached;
use Exporter 'import';
our @EXPORT = qw(mem_get);
my $mem;

sub mem_get {
  $mem = _mem_init() unless $mem; # подключаемся к серверу
  return $mem;
}

# инициализация соединения с memcached
sub _mem_init {
  $mem = Cache::Memcached->new( { servers  => ["$MEM_SERVER:$MEM_PORT"], debug => 0 } ); 
  return $mem;
}

1;
