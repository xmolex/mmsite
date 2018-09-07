package Mmsite::Lib::Members::View;
################################################################################
#  Управление просмотренными через плеер видео
################################################################################
# настройки
################################################################################
my $SUF_DATA       = 'view_';       # суффикс ключа memcached для хранения данных
my $SUF_DATA_GROUP = 'view_group_'; # суффикс ключа memcached для хранения данных по группе
################################################################################
use Modern::Perl;
use utf8;
use Mmsite::Lib::Vars;
use Mmsite::Lib::Db;
use Mmsite::Lib::Files;
use Mmsite::Lib::Groups;
use Mmsite::Lib::Mem;

sub is_view {
    # просматривал ли пользователь файл в плеере, возвращаем булево
    my ( $self, $file_id ) = @_;
    return unless $self->id;
    return unless Mmsite::Lib::Files->new($file_id);
    
    # пытаемся взять из кеша
    my $key = $SUF_DATA . $self->id . '_' . $file_id;
    my $memcached = mem_get()->get($key);
    return $memcached if defined $memcached;
    
    # берем данные из базы
    $memcached = 0;
    my $sql = sql("SELECT file_id FROM member_views WHERE member_id = '" . $self->id . "' AND file_id = '$file_id';");
    if ($$sql[0]) {
        $memcached = 1;
    }
    
    # заносим данные в кэш
    mem_get()->delete($key);
    mem_get()->add( $key, $memcached );

    return $memcached;
}

sub is_view_unlooked {
    # есть ли в объекте группы непросмотренные файлы
    my ( $self, $group_id ) = @_;
    return unless $self->id;
    return unless Mmsite::Lib::Groups->new($group_id);
    
    # пытаемся взять из кеша
    my $key = $SUF_DATA_GROUP . $self->id . '_' . $group_id;
    my $memcached = mem_get()->get($key);
    return $memcached if defined $memcached;
    
    # берем данные из базы
    $memcached = 0;
    my $sql = sql("SELECT count(id) FROM files WHERE parent_id = '$group_id' AND type = 0 AND id NOT IN (SELECT file_id FROM member_views WHERE member_id = '" . $self->id . "');");
    if ($$sql[0]) {
        $memcached = 1;
    }
    
    # заносим данные в кэш
    mem_get()->delete($key);
    mem_get()->add( $key, $memcached );

    return $memcached;
}

sub view_create {
    # указываем, что пользователь просматривал данный файл в плеере
    my ( $self, $file_id ) = @_;
    return unless $self->id;
    return unless Mmsite::Lib::Files->new($file_id);
    
    $self->view_delete($file_id);
    sql( "INSERT INTO member_views ( member_id, file_id ) VALUES ( " . $self->id . ", $file_id );", 1 );
    $self->view_clear_cache_data($file_id); # чистим кеш
    # для группы кеш не чистим, т.к. он будет очищен при вызове $self->view_delete
    return 1;
}

sub view_create_all_from_group {
    # указываем, что пользователь просматривал все файлы объекта группы в плеере
    # возвращаем массив из идентификаторов файлов
    my ( $self, $group_id ) = @_;
    return unless $self->id;
    
    my $obj_group = Mmsite::Lib::Groups->new($group_id);
    return unless $obj_group;
    
    my @ids;
    my @mass = $obj_group->get_files('view');
    
    for( my $i = 0; $i < @mass; $i = $i + 13 ) {
        # если статус web и удалось установить просмотр
        if ( $mass[$i+6] && $self->view_create($mass[$i]) ) {
            # добавляем в массив для вывода
            push @ids, $mass[$i];
        }
    }
    
    return @ids;
}

sub view_delete {
    # удаляем привязку о том, что пользователь просматривал данный файл в плеере
    my ( $self, $file_id ) = @_;
    return unless $self->id;
    
    my $obj_file = Mmsite::Lib::Files->new($file_id);
    return unless $obj_file;
    
    $obj_file->get();
    
    sql( "DELETE FROM member_views WHERE member_id = '" . $self->id . "' AND file_id = '$file_id';", 1 );
    $self->view_clear_cache_data($file_id); # чистим кеш
    $self->view_clear_cache_data_for_group($obj_file->parent_id); # чистим кеш для группы
    return 1;
}

sub view_delete_all_from_group {
    # удаляем привязку о том, что пользователь просматривал все файлы объекта группы в плеере
    # возвращаем массив из идентификаторов файлов
    my ( $self, $group_id ) = @_;
    return unless $self->id;
    
    my $obj_group = Mmsite::Lib::Groups->new($group_id);
    return unless $obj_group;
    
    my $sql = sql("DELETE FROM member_views WHERE member_id = '" . $self->id . "' AND file_id IN ( SELECT id FROM files WHERE parent_id='$group_id' AND is_web=TRUE AND type=0 ) RETURNING file_id;");
    if ( ref $sql eq 'ARRAY' ) {
        $self->view_clear_cache_data($_) for @$sql; # чистим кеш
        $self->view_clear_cache_data_for_group($obj_group->id); # чистим кеш для группы
        return @$sql;
    }
    
    return;
}

sub view_delete_force {
    # удаление без указания пользователя
    my $file_id = shift;
    return unless Mmsite::Lib::Files->new($file_id);
    sql( "DELETE FROM member_views WHERE file_id = '$file_id';", 1 );
    return 1;
}

# метод очистки данных объекта в кеше
sub view_clear_cache_data {
    my ( $self, $file_id ) = @_;
    my $key = $SUF_DATA . $self->id . '_' . $file_id;
    mem_get()->delete($key);
    return;
}

sub view_clear_cache_data_for_group {
    my ( $self, $group_id ) = @_;
    my $key = $SUF_DATA_GROUP . $self->id . '_' . $group_id;
    mem_get()->delete($key);
    return;
}

# запрос на очистку всех кешированных значений о том, что у пользователя есть непросмотренные файлы для объекта группы
sub view_clear_all_cache_data_for_group {
    my ( $group_id ) = @_;
    my $sql = sql("SELECT member_id FROM member_subscribes WHERE group_id='$group_id';");
    if ($$sql[0]) {
        for my $member_id (@$sql) {
            my $key = $SUF_DATA_GROUP . $member_id . '_' . $group_id;
            mem_get()->delete($key);
        }
    }
    return;
}

1;
