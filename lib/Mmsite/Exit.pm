######################################################################################
# механизм сброса сессии пользователя
######################################################################################
package Mmsite::Exit;
use Dancer2 appname => 'Mmsite';
use Modern::Perl;
use utf8;
use Mmsite::Lib::Vars;

prefix '/exit';

# процесс очистки сессии пользователя
get '' => sub {
    # чистим куки от сессии
    cookie $AUTH_COOKIE_VK_ID   => 0, expires => "-1 hours";
    cookie $AUTH_COOKIE_VK_SESS => 0, expires => "-1 hours";

    # переходим на исходную страницу
    my $redir = query_parameters->get('from') || '/';
    redirect $redir;

};

1;
