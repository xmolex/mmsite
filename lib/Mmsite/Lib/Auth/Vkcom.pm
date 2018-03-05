######################################################################################
# механизм аутентификации в vk.com
######################################################################################
package Mmsite::Lib::Auth::Vkcom;

######################################################################################
# НАСТРОЙКИ
######################################################################################
my $DOWNLOAD_AGENT   = 'Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0; .NET CLR 2.0.50727; .NET CLR 3.0.4506.2152; .NET CLR 3.5.30729; .NET4.0C)'; # заголовок агента
my $DOWNLOAD_ACCEPT  = 'text/html, */*;q=0.1'; # заголовок accept
my $DOWNLOAD_TIMEOUT = 2; # timeout
######################################################################################

use Modern::Perl;
use utf8;
use LWP 5.64;
use Mmsite::Lib::Vars;
use JSON::XS;


sub new {
    my ($class) = @_;
    my $self = bless {}, $class;
    
    # инициализируем экземпляр агента
    my $browser = LWP::UserAgent->new;
    $browser->agent($DOWNLOAD_AGENT);
    $browser->timeout($DOWNLOAD_TIMEOUT);
    
    $self->{'BROWSER'} = $browser;

    return $self;
}


sub vk_get_user_code {
   my ($self) = @_;
   return("https://oauth.vk.com/authorize?client_id=$AUTH_VK_ID&display=page&scope=0&response_type=code&v=$AUTH_VK_VER&redirect_uri=http://" . $SITE_NAME . "/auth_vk");
}

sub vk_get_access_token {
  my ( $self, $user_code ) = @_;
  my ( $code, $data ) = $self->vk_get("https://oauth.vk.com/access_token?client_id=$AUTH_VK_ID&client_secret=$AUTH_VK_KEY&redirect_uri=http://" . $SITE_NAME . "/auth_vk&code=$user_code");
  
  # если запрос не удался, то выходим
  return( '', 0 ) if $code != 200;

  # разбираем данные  
  my $access_token = '';
  my $expires = 0;
  my $user_id = 0;
  my $index = index( $data, "access_token" ); if ($index == -1) {return();}
  $data = substr( $data, $index + 15 );
  $access_token = substr( $data, 0, index( $data, '"' ) );
  $data = substr( $data, index( $data, 'expires_in' ) + 12 );
  $expires = scalar( substr( $data, 0, index( $data, ',' ) ) );
  if ($expires != 0) { $expires = time() + $expires; }
  $data = substr( $data, index( $data, 'user_id' ) + 9 );
  $user_id = scalar( substr( $data, 0, index( $data, '}' ) ) );
  return( $access_token, $user_id );
}


sub vk_get_user_name {
  # получаем токен, vkid и отдаем имя или ошибку
  my ( $self, $vksess, $vkid ) = @_;
  return if (!$vksess || !$vkid );
  
  my ( $code, $data ) = $self->vk_get("https://api.vk.com/method/users.get?owner_id=$vkid&v=$AUTH_VK_VER&access_token=$vksess&fields=first_name,last_name");
  
  _to_log("Request: " . "https://api.vk.com/method/users.get?owner_id=$vkid&v=$AUTH_VK_VER&access_token=$vksess&fields=first_name,last_name");
  
  # если запрос не удался, то выходим
  if ($code != 200) {
      _to_log('error: получен код ' . $code);
      return('error: не удалось обработать ответ от vk.com, получен код ' . $code);
  }
  
  
  my $json_data;
  on_utf8(\$data);
  my $json_xs = JSON::XS->new();
  
  _to_log('get: ' . $data);

  # разбираем данные
  unless (eval { $json_data = $json_xs->decode($data) } ) {
      _to_log('error: не удалось распарсить json');
      return('error: не удалось обработать ответ от vk.com, неверная структура <br>' . $data);
  }
  
  on_utf8(\$json_data);
  my $json = $$json_data{'error'}; if ( ref($json) eq 'HASH' ) { return( 'error: ' . _vk_auth_error($json) ); }
  $json = $$json_data{'response'};
  $json = $$json[0];
  
  my $first_name = $$json{'first_name'};
  my $last_name  = $$json{'last_name'};
  
  return "$first_name $last_name";
}

# получаем данные из сетевого ресурса
# принимаем url, возвращаем код статуса и содержимое
sub vk_get {
    my ( $self, $addr ) = @_;
    my $req = HTTP::Request->new(GET => $addr);
    $req->header(Accept => $DOWNLOAD_ACCEPT);
    my ( $code, $data ) = ( '','' );
    my $res = $self->{'BROWSER'}->request($req);
    if ($res->status_line =~ m/^(\d+)/) {$code = $1;} else {$code = 0;}
    $data = $res->decoded_content;
    on_utf8(\$data);
    return( $code, $data );
}


# парсим ошибку API vk.com
sub _vk_auth_error {
  # получаем кеш с ошибкой и обрабатываем его, возвращая сообщение об ошибке
  my ( $ref ) = @_;
  my $error = '';
  if ($$ref{'error_code'} == 5) {
    # проблема с авторизацией, сбрасываем сессию
  }
  $error = $$ref{'error_msg'};
  on_utf8(\$error);
  _to_log('error: ошибка авторизации: code=' . $$ref{'error_code'} . ', msg=' . $$ref{'error_msg'});
  return $error;
}

# пишем в лог
sub _to_log {
    open my $fh, ">>:utf8", $PATH_LOG_VK;
    return unless $fh;
    say $fh get_sql_time() . "\t" . $_[0];
    close $fh;
}

1;

