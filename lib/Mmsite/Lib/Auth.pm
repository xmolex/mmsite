################################################################################
# Модуль авторизации
################################################################################
package Mmsite::Lib::Auth;

use Modern::Perl;
use utf8;
use CGI qw(:cgi);
use Mmsite::Lib::Vars;
use Mmsite::Lib::Db;
use Mmsite::Lib::Mem;
use Mmsite::Lib::Auth::Vkcom;
use Exporter 'import';
our @EXPORT = qw(Auth);

################################################################################
# настройки
################################################################################
my $CACHE_TIME = 180; # количество секунд хранения в memcached
my $GUEST = 'Гость'; # отображаемое имя неавторизованного пользователя
################################################################################


my %sess_already;

# функция возвращает данные авторизованности текущего пользователя
sub Auth {
    # получаем pface_sess1, pface_sess2, vk_id, vk_sess
    # выдаем идентификатор, отображаемое имя, права, флаг системы авторизации и идентификатор в этой системе
    my ( $user_id, $user_name, $user_role, $sys, $sys_id ); # sys: 1 - pface.ru, 2 - vk.com

    on_utf8(\$GUEST);
  
    # проверяем кеш
    my $memcached = '';
  
    # pface: пытаемся получиться данные
    my $pface_s1 = $_[0];
    my $pface_s2 = $_[1];
    if (!$pface_s1) { $pface_s1 = cookie($AUTH_COOKIE_PFACE_1) || 0; }
    if (!$pface_s2) { $pface_s2 = cookie($AUTH_COOKIE_PFACE_2) || 0; }
    if ($pface_s1 && $pface_s2) {
        # какие-то данные есть, пробуем взять из кеша
        #$memcached = $ENV{'MEM'}->get('auth_'.$pface_s1.$pface_s2);
    }
  
    # vk.com: пытаемся получиться данные
    my $vk_user_id   = $_[2] || 0;
    my $vk_user_sess = $_[3] || 0;
    if (!$memcached) {
        # проверяем по кешу vk.com
        if (!$vk_user_id)   { $vk_user_id   = cookie($AUTH_COOKIE_VK_ID)   || 0; }
        if (!$vk_user_sess) { $vk_user_sess = cookie($AUTH_COOKIE_VK_SESS) || 0; }
      
        if ($vk_user_id && $vk_user_sess) {
            # какие-то данные есть, пробуем взять из кеша
            $memcached = mem_get()->get( 'auth_' . $vk_user_id . $vk_user_sess );
        }
    }

    # если данные есть в кеше, то используем их
    if ($memcached) {
        # есть данные в кеше
        on_utf8(\$memcached);
        ( $user_id, $user_name, $user_role, $sys, $sys_id ) = split "\n", $memcached;
        return( $user_id, $user_name, $user_role, $sys, $sys_id );
    }
  
    # проверяем на авторизацию в pface.ru
    #( $user_id, $user_name ) = PfaceAuth( $s1, $s2 );
    #if ($user_id) {
    #    $sys = 1;
    #    $sys_id = $user_id;
    #}
  
    if (!$user_id) {
        # проверяем на авторизацию в vk.com
        ( $user_id, $user_name ) = _vkcom_auth( $vk_user_id, $vk_user_sess );
        if ($user_id) {
            $sys = 2;
            $sys_id = $user_id;
        }
    }
  
    # к этому шагу мы должны быть авторизованы, если авторизация ни по какому шагу не прошла, перед нами неавторизованный пользователь
    if (!$sys) { return( 0, $GUEST, 0, 0, 0 ); }
  
    # авторизация прошла
    # собираем системные данные о пользователе в зависимости от системы аутентификации
    my $sql;
    if ($sys == 1) {
        # авторизация по pface
        $sql = sql("SELECT id,title,role,pface_id FROM members WHERE vk_id = '$sys_id'");
        if ($$sql[0]) { # пользователь нашелся
            $user_id   = $$sql[0];
            $user_name = $$sql[1];
            $user_role = $$sql[2];
            $sys_id    = $$sql[3];
        }
        else { 
            # пользователь авторизован по pface, но не существует в базе
            # необходимо создать учетку
            $sql = sql("INSERT INTO members (title,role,pface_id) VALUES ('$user_name',1,$sys_id) RETURNING id;");
            $user_id = $$sql[0];
            $user_role = 1;
        }
    }
    elsif ($sys == 2) {
        # авторизация по vk.com
        $sql = sql("SELECT id,title,role,vk_id FROM members WHERE vk_id = '$sys_id'");
        if ($$sql[0]) { # пользователь нашелся
            $user_id   = $$sql[0];
            $user_name = $$sql[1];
            $user_role = $$sql[2];
            $sys_id    = $$sql[3];
        }
        else {
            # пользователь авторизован по vk.com, но не существует в базе
            # необходимо создать учетку
            $sql = sql("INSERT INTO members (title,role,vk_id) VALUES ('$user_name',1,$sys_id) RETURNING id;");
            $user_id   = $$sql[0];
            $user_role = 1;
        }
    }

    # если авторизация есть, заносим данные в кеш
    if ($user_id) {
        $memcached = $user_id."\n".$user_name."\n".$user_role."\n".$sys."\n".$sys_id;
    
        if ($pface_s1 && $pface_s2) {
            # pface
            #$ENV{'MEM'}->add( 'auth_'.$pface_s1.$pface_s2, $memcached, $CACHE_TIME );
        }
        elsif ($vk_user_id && $vk_user_sess) {
            # vk.com
            mem_get()->add( 'auth_'.$vk_user_id.$vk_user_sess, $memcached, $CACHE_TIME );
        }
    
    }
  
    return( $user_id, $user_name, $user_role, $sys, $sys_id );
}



sub _vkcom_auth {
    # функция определения авторизован ли пользователь
    # выдаем идентификатор пользователя, его отображаемое имя
    my $vk_user_id   = cookie($AUTH_COOKIE_VK_ID)   || 0;
    my $vk_user_sess = cookie($AUTH_COOKIE_VK_SESS) || 0;
  
    if (!$vk_user_id || !$vk_user_sess) {
        # если данных нет в куках, то их могли передать напрямую
        $vk_user_id   = $_[0] || 0;
        $vk_user_sess = $_[1] || 0;
    } 
  
    # проверка на правильность данных
    $vk_user_id   = 0 if $vk_user_id   !~ m/^\d+$/;
    $vk_user_sess = 0 if $vk_user_sess !~ m/^\w+$/i;
  
    # если данные точно не верные, то отдаем гостя
    return( 0, $GUEST ) if ( !$vk_user_id || !$vk_user_sess );
    
    # проверяем не была ли под этой сессией уже неудачная авторизация
    return( 0, $GUEST ) if exists $sess_already{$vk_user_sess};
    
    # инициализируем экземпляр vk.com
    my $vkreq = Mmsite::Lib::Auth::Vkcom->new();
    
    # пытаемся получить имя, через API vk.com с авторизационными данными пользователя
    my $name = $vkreq->vk_get_user_name( $vk_user_sess, $vk_user_id );
    
    if ($name =~ /^error:/) {
        # возникла ошибка с авторизацией
        $sess_already{$vk_user_sess} = 1;
        return( 0, $GUEST );
    }
    
    # авторизация успешна
    delete $sess_already{$vk_user_sess} if exists $sess_already{$vk_user_sess};
    return( $vk_user_id, $name );
}

1;
