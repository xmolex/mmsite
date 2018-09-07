package Mmsite::Auth_pface;
######################################################################################
# механизм аутентификации пользователя в pface.ru
######################################################################################
# НАСТРОЙКИ
######################################################################################
my $DOWNLOAD_AGENT   = 'Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0; .NET CLR 2.0.50727; .NET CLR 3.0.4506.2152; .NET CLR 3.5.30729; .NET4.0C)'; # заголовок агента
my $DOWNLOAD_ACCEPT  = 'text/html, */*;q=0.1'; # заголовок accept
my $DOWNLOAD_TIMEOUT = 2; # timeout
######################################################################################
use Dancer2 appname => 'Mmsite';
use Modern::Perl;
use utf8;
use LWP 5.64;
use Mmsite::Lib::Vars;
use Mmsite::Lib::Members::Auth::Pfaceru;

prefix '/auth_pface';

# процесс аутентификацию через pface.ru
get '' => sub {
    # сохраняем информацию откуда пришли
    my $from = query_parameters->get('from');
    if ($from) {
        # сохраняем в кукис
        cookie $AUTH_COOKIE_FROM => $from;
    }

    # получаем параметры
    my $sess1 = query_parameters->get('sess1');
    my $sess2 = query_parameters->get('sess2');
    
    if ( !$sess1 || !$sess2 ) {
        # авторизации нет, переходим на страницу авторизации
        redirect 'http://a.pface.ru/?' . $SITE_URL . 'auth_pface';
    }
    
    # инициализируем экземпляр pface.ru
    my $pfacereq = Mmsite::Lib::Members::Auth::Pfaceru->new();
    

    # пытаемся получить имя, через API pface.ru
    my ( $name, $id ) = $pfacereq->vk_get_user_name( $sess1, $sess2, $ENV{'REMOTE_ADDR'} );
    return $name if $name =~ m/^error:/; # возникла ошибка с авторизацией
      
    # сохраняем данные сессии в куки
    my $redir = cookie($AUTH_COOKIE_FROM) || '/';
    cookie $AUTH_COOKIE_PFACE_1 => $sess1, expires => "30 days";
    cookie $AUTH_COOKIE_PFACE_2 => $sess2, expires => "30 days";
    cookie $AUTH_COOKIE_FROM => 0,         expires => "-1 hours";
    redirect $redir;

};

1;
