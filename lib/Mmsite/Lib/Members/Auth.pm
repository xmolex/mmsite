package Mmsite::Lib::Members::Auth;
################################################################################
#  Управление просмотренными через плеер видео
################################################################################
# настройки
################################################################################
my $CACHE_TIME = 180; # количество секунд хранения в memcached
my $GUEST = 'Гость'; # отображаемое имя неавторизованного пользователя
################################################################################
use Modern::Perl;
use utf8;
use CGI qw(:cgi);
use Mmsite::Lib::Vars;
use Mmsite::Lib::Subs;
use Mmsite::Lib::Db;
use Mmsite::Lib::Mem;
use Mmsite::Lib::Members::Auth::Vkcom;
use Mmsite::Lib::Members::Auth::Pfaceru;

my %sess_already;
on_utf8(\$GUEST);

# функция возвращает данные авторизованности текущего пользователя
sub auth {
    my $self = shift;

    # получаем pface_sess1, pface_sess2, vk_id, vk_sess
    # в процессе устанавливаем идентификатор, отображаемое имя, права, флаг системы авторизации и идентификатор в этой системе
    # auth_sys: 1 - pface.ru, 2 - vk.com
  
    # проверяем кеш
    my $memcached = '';
  
    # pface: пытаемся получиться данные
    my $pface_s1 = $_[0];
    my $pface_s2 = $_[1];
    if (! $pface_s1) { $pface_s1 = cookie($AUTH_COOKIE_PFACE_1) || 0; }
    if (! $pface_s2) { $pface_s2 = cookie($AUTH_COOKIE_PFACE_2) || 0; }
    if ( $pface_s1 && $pface_s2 ) {
        # какие-то данные есть, пробуем взять из кеша
        $memcached = mem_get()->get('auth_' . $pface_s1 . $pface_s2);
    }
  
    # vk.com: пытаемся получиться данные
    my $vk_user_id   = $_[2] || 0;
    my $vk_user_sess = $_[3] || 0;
    if (!$memcached) {
        # проверяем по кешу vk.com
        if (! $vk_user_id)   { $vk_user_id   = cookie($AUTH_COOKIE_VK_ID)   || 0; }
        if (! $vk_user_sess) { $vk_user_sess = cookie($AUTH_COOKIE_VK_SESS) || 0; }
      
        if ( $vk_user_id && $vk_user_sess ) {
            # какие-то данные есть, пробуем взять из кеша
            $memcached = mem_get()->get( 'auth_' . $vk_user_id . $vk_user_sess );
        }
    }

    # если данные есть в кеше, то используем их
    if ($memcached) {
        # есть данные в кеше
        on_utf8(\$memcached);
        ( $self->{'id'}, $self->{'name'}, $self->{'role'}, $self->{'auth_sys'}, $self->{'auth_sys_id'} ) = split "\n", $memcached;
        return;
    }
  
    # проверяем на авторизацию в pface.ru
    ( $self->{'id'}, $self->{'name'} ) = _pface_auth( $pface_s1, $pface_s2 );
    if ($self->{'id'}) {
        $self->{'auth_sys'}    = 1;
        $self->{'auth_sys_id'} = $self->{'id'};
    }
  
    if (! $self->{'id'}) {
        # проверяем на авторизацию в vk.com
        ( $self->{'id'}, $self->{'name'} ) = _vkcom_auth( $vk_user_id, $vk_user_sess );
        if ($self->{'id'}) {
            $self->{'auth_sys'}    = 2;
            $self->{'auth_sys_id'} = $self->{'id'};
        }
    }
  
    # к этому шагу мы должны быть авторизованы, если авторизация ни по какому шагу не прошла, перед нами неавторизованный пользователь
    if (!$self->{'auth_sys'}) {
        $self->{'id'}          = 0;
        $self->{'name'}        = $GUEST;
        $self->{'role'}        = 0;
        $self->{'auth_sys'}    = 0;
        $self->{'auth_sys_id'} = 0;
    }
  
    # авторизация прошла
    # собираем системные данные о пользователе в зависимости от системы аутентификации
    my $sql;
    if ($self->{'auth_sys'} == 1) {
        # авторизация по pface
        $sql = sql("SELECT id,title,role,pface_id FROM members WHERE pface_id = '$self->{'auth_sys_id'}'");
        if ($$sql[0]) { # пользователь нашелся
            $self->{'id'}          = $$sql[0];
            $self->{'name'}        = $$sql[1];
            $self->{'role'}        = $$sql[2];
            $self->{'auth_sys_id'} = $$sql[3];
        }
        else { 
            # пользователь авторизован по pface, но не существует в базе
            # необходимо создать учетку
            $sql = sql("INSERT INTO members (title,role,pface_id) VALUES ( '$self->{'name'}', 1, $self->{'auth_sys_id'} ) RETURNING id;");
            $self->{'id'}   = $$sql[0];
            $self->{'role'} = 1;
        }
    }
    elsif ($self->{'auth_sys'} == 2) {
        # авторизация по vk.com
        $sql = sql("SELECT id,title,role,vk_id FROM members WHERE vk_id = '$self->{'auth_sys_id'}'");
        if ($$sql[0]) { # пользователь нашелся
            $self->{'id'}          = $$sql[0];
            $self->{'name'}        = $$sql[1];
            $self->{'role'}        = $$sql[2];
            $self->{'auth_sys_id'} = $$sql[3];
        }
        else {
            # пользователь авторизован по vk.com, но не существует в базе
            # необходимо создать учетку
            $sql = sql("INSERT INTO members (title,role,vk_id) VALUES ( '$self->{'name'}', 1, $self->{'auth_sys_id'} ) RETURNING id;");
            $self->{'id'}   = $$sql[0];
            $self->{'role'} = 1;
        }
    }

    # если авторизация есть, заносим данные в кеш
    if ($self->{'id'}) {
        $memcached = join "\n", ( $self->{'id'}, $self->{'name'}, $self->{'role'}, $self->{'auth_sys'}, $self->{'auth_sys_id'} );
    
        if ($pface_s1 && $pface_s2) {
            # pface
            mem_get()->add( 'auth_'.$pface_s1.$pface_s2, $memcached, $CACHE_TIME );
        }
        elsif ($vk_user_id && $vk_user_sess) {
            # vk.com
            mem_get()->add( 'auth_'.$vk_user_id.$vk_user_sess, $memcached, $CACHE_TIME );
        }
    
    }
  
    return;
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
    if ($vk_user_id   !~ m/^\d+$/)  {$vk_user_id   = 0;}
    if ($vk_user_sess !~ m/^\w+$/i) {$vk_user_sess = 0;}
  
    # если данные точно не верные, то отдаем гостя
    return( 0, $GUEST ) if ( !$vk_user_id || !$vk_user_sess );
    
    # проверяем не была ли под этой сессией уже неудачная авторизация
    return( 0, $GUEST ) if exists $sess_already{$vk_user_sess};
    
    # инициализируем экземпляр vk.com
    my $vkreq = Mmsite::Lib::Members::Auth::Vkcom->new();
    
    # пытаемся получить имя, через API vk.com с авторизационными данными пользователя
    my $name = $vkreq->vk_get_user_name( $vk_user_sess, $vk_user_id );
    
    if ($name =~ /^error:/) {
        # возникла ошибка с авторизацией
        $sess_already{$vk_user_sess} = 1;
        return( 0, $GUEST );
    }
    
    # авторизация успешна
    if ( exists $sess_already{$vk_user_sess} ) {
        delete $sess_already{$vk_user_sess};
    }
    return( $vk_user_id, $name );
}

sub _pface_auth {
    # функция определения авторизован ли пользователь
    # выдаем идентификатор пользователя, его отображаемое имя
    my $pface_user_s1 = cookie($AUTH_COOKIE_PFACE_1)   || 0;
    my $pface_user_s2 = cookie($AUTH_COOKIE_PFACE_2) || 0;
  
    if (!$pface_user_s1 || !$pface_user_s2) {
        # если данных нет в куках, то их могли передать напрямую
        $pface_user_s1 = $_[0] || 0;
        $pface_user_s2 = $_[1] || 0;
    } 
  
    # проверка на правильность данных
    if ($pface_user_s1 !~ m/^\w+$/)  {$pface_user_s1 = 0;}
    if ($pface_user_s2 !~ m/^\w+$/i) {$pface_user_s2 = 0;}
  
    # если данные точно не верные, то отдаем гостя
    return( 0, $GUEST ) if ( !$pface_user_s1 || !$pface_user_s2 );
    
    my $total_sess = $pface_user_s1 . $pface_user_s2;
    
    # проверяем не была ли под этой сессией уже неудачная авторизация
    return( 0, $GUEST ) if exists $sess_already{$total_sess};
    
    # инициализируем экземпляр pface.ru
    my $pfacereq = Mmsite::Lib::Members::Auth::Pfaceru->new();
    
    # пытаемся получить имя и идентификатор с авторизационными данными пользователя
    my ( $name, $id ) = $pfacereq->vk_get_user_name( $pface_user_s1, $pface_user_s2, $ENV{'REMOTE_ADDR'} );
    
    if ($name =~ /^error:/) {
        # возникла ошибка с авторизацией
        $sess_already{$total_sess} = 1;
        return( 0, $GUEST );
    }
    
    # авторизация успешна
    if ( exists $sess_already{$total_sess} ) {
        delete $sess_already{$total_sess};
    }
    return( $id, $name );
}

1;
