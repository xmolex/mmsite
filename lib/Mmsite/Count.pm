package Mmsite::Count;
######################################################################################
# подсчет скачанных и просмотренных файлов
######################################################################################
# настройки
######################################################################################
use constant TIMER        => 3600; # количество секунд защиты от фрода на основе IP
use constant SUF_DOWNLOAD => 'download_'; # суффикс ключа memcached для скачивания
use constant SUF_VIEW     => 'view_'; # суффикс ключа memcached для просмотра
######################################################################################
use Dancer2 appname => 'Mmsite';
use Modern::Perl;
use utf8;
use Mmsite::Lib::Vars;
use Mmsite::Lib::Files;
use Mmsite::Lib::Groups;
use Mmsite::Lib::Mem;

prefix '/count';

# инкрементируем файл
post '' => sub {
    # получаем идентификатор файла
    my $file_id = body_parameters->get('file_id');
    return unless $file_id;
    
    # получаем вариант использования, истина - просмотр через плеер, ложь - скачивание
    my $target = body_parameters->get('target');

    # инициализация объекта файла
    my $obj_file = Mmsite::Lib::Files->new($file_id);
    return unless $obj_file;
    
    # пробуем получить значение из кеша, чтобы защититься от фрода
    my $suf = $target ? SUF_VIEW : SUF_DOWNLOAD;
    my $key = $suf . $file_id . '_' . request_header('X-Real-IP');
    my $memcached = mem_get()->get($key);
    return if $memcached;
    
    # получаем данные
    return unless ( $obj_file->get() );
    
    # инкрементируем и устанавливаем
    if ($target) {
        # просмотр через плеер
        $obj_file->set( 'count_view', $obj_file->count_view + 1 );
    }
    else {
        # скачивание
        $obj_file->set( 'count_download', $obj_file->count_download + 1 );
    }
    
    # обнуляем кеш у объекта группы
    my $obj_group = Mmsite::Lib::Groups->new( $obj_file->parent_id );
    if ($obj_group) {
        $obj_group->clear_cache_data_file();
    }
    
    # заносим в кеш
    mem_get()->delete($key);
    mem_get()->add( $key, 1, TIMER );

    return 1;
};

1;
