######################################################################################
# механизм аутентификации пользователя в vk.com
######################################################################################
package Mmsite::Auth_vk;

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
use Mmsite::Lib::Auth::Vkcom;


prefix '/auth_vk';

# процесс аутентификацию через vk.com
get '' => sub {
    # сохраняем информацию откуда пришли
    my $vk_from = query_parameters->get('from');
    if ($vk_from) {
        # сохраняем в кукис
        cookie $AUTH_COOKIE_VK_FROM => $vk_from;
    }

    # получаем параметры
    my $code              = query_parameters->get('code');
    my $error             = query_parameters->get('error');
    my $error_description = query_parameters->get('error_description');
    
    # если есть флаг ошибки, значит выводим ее описание
    return $error_description if $error; # ошибка авторизации
    
    # инициализируем экземпляр vk.com
    my $vkreq = Mmsite::Lib::Auth::Vkcom->new();
    
    # если кода нет, его нужно получить
    if (!$code =~ m/\d/) {
        # переходим на страницу авторизации vk.com
        my $tt = $vkreq->vk_get_user_code();
        redirect $tt;
    }
    else {
      # код есть, получаем access_token
      my ( $access_token, $user_id ) = $vkreq->vk_get_access_token($code);
      if ($access_token) {
        # пытаемся получить имя, через API vk.com
        my $name = $vkreq->vk_get_user_name( $access_token, $user_id );
        return $name if $name =~ m/^error:/; # возникла ошибка с авторизацией
      
        # сохраняем данные сессии в куки
        my $redir = cookie $AUTH_COOKIE_VK_FROM || '/';
        cookie $AUTH_COOKIE_VK_ID   => $user_id,      expires => "30 days";
        cookie $AUTH_COOKIE_VK_SESS => $access_token, expires => "30 days";
        cookie $AUTH_COOKIE_VK_FROM => 0,             expires => "-1 hours";
        redirect $redir;
        
      } else {
          # не удалось получить access_token
          return "Не удалось авторизоваться";
      }
    }
};

1;
