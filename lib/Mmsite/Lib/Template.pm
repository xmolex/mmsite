################################################################################
# Модуль работы с модульными шаблонами
################################################################################
package Mmsite::Lib::Template;

################################################################################
# настройки
################################################################################
my $TEMPL_SUF     = 'lib_templ_'; # суффикс для memcached ключа
my $PATH_TEMPLATE = 'lib';        # поддиректория шаблонов для модулей
################################################################################

use Modern::Perl;
use utf8;
use Mmsite::Lib::Vars;
use Mmsite::Lib::Mem;
use Exporter 'import';
our @EXPORT = qw(template_get);



# функция получает имя модульного шаблона и возвращает его код
sub template_get {
    my ($template) = @_;
    
    # пытаемся взять значение из кеша
    my $key = $TEMPL_SUF . $template;
    my $memcached = mem_get()->get($key);
    if ($memcached) {
        # есть сохраненное значение
        on_utf8(\$memcached);
        return $memcached;
    }
    
    # пытаемся взять значение из файла
    my $local_file = "$PATH_TEMPLATES/$template" . ".tt";
    open my $fh, "<:utf8", $local_file;
    return unless $fh;
    
    # файл с шаблоном открыли, обрабатываем
    $memcached = '';
    $memcached .= $_ for (<$fh>);
    
    close $fh;
        
    # сохраняем значение в кеш
    mem_get()->delete( $key );
    mem_get()->add( $key, $memcached );
        
    # возвращаем значение
    return $memcached;
}

1;
