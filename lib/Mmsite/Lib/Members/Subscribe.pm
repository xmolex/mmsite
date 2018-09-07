package Mmsite::Lib::Members::Subscribe;
################################################################################
#  Управление подпиской
################################################################################
# настройки
################################################################################
my $SUF_DATA       = 'subscribe_'; # суффикс ключа memcached для хранения данных
################################################################################
use Modern::Perl;
use utf8;
use Mmsite::Lib::Vars;
use Mmsite::Lib::Db;
use Mmsite::Lib::Groups;
use Mmsite::Lib::Mem;

sub is_subscribe {
    # подписан ли пользователь на объект группы, возвращаем булево
    my ( $self, $group_id ) = @_;
    return unless $self->id;
    return unless Mmsite::Lib::Groups->new($group_id);
    
    # пытаемся взять из кеша
    my $key = $SUF_DATA . $self->id . '_' . $group_id;
    my $memcached = mem_get()->get($key);
    return $memcached if defined $memcached;
    
    # берем данные из базы
    $memcached = 0;
    my $sql = sql("SELECT group_id FROM member_subscribes WHERE member_id = '" . $self->id . "' AND group_id = '$group_id';");
    if ($$sql[0]) {
        $memcached = 1;
    }
    
    # заносим данные в кэш
    mem_get()->delete($key);
    mem_get()->add( $key, $memcached );

    return $memcached;
}

sub subscribes {
    # возвращаем массив с подписками на объект группы пользователя
    my ( $self, $group_id ) = @_;
    return unless $self->id;
    my $sql = sql("SELECT group_id FROM member_subscribes WHERE member_id = '" . $self->id . "' ORDER BY id;");
    return @$sql;
}

sub subscribe_create {
    # создаем подписку на объект группы пользователем
    my ( $self, $group_id ) = @_;
    return unless $self->id;
    return unless Mmsite::Lib::Groups->new($group_id);
    $self->subscribe_delete($group_id);
    sql( "INSERT INTO member_subscribes ( member_id, group_id ) VALUES ( " . $self->id . ", $group_id );", 1 );
    # чистку кеша пропускаем, т.к. она была при вызове $self->subscribe_delete;
    return 1;
}

sub subscribe_delete {
    # удаляем подписку на объект группы пользователем
    my ( $self, $group_id ) = @_;
    return unless $self->id;
    return unless Mmsite::Lib::Groups->new($group_id);
    sql( "DELETE FROM member_subscribes WHERE member_id = '" . $self->id . "' AND group_id = '$group_id';", 1 );
    $self->subscribe_clear_cache_data($group_id); # чистим кеш
    return 1;
}

sub subscribe_delete_force {
    # удаление без указания пользователя
    my $group_id = shift;
    return unless Mmsite::Lib::Groups->new($group_id);
    sql( "DELETE FROM member_subscribes WHERE group_id = '$group_id';", 1 );
    return 1;
}

# метод очистки данных объекта в кеше
sub subscribe_clear_cache_data {
    my ( $self, $group_id ) = @_;
    my $key = $SUF_DATA . $self->id . '_' . $group_id;
    mem_get()->delete($key);
    return;
}

1;
