package Mmsite::Lib::Members::Auth::Pfaceru;
######################################################################################
# механизм аутентификации в pface.ru
######################################################################################
use Modern::Perl;
use utf8;
use Mmsite::Lib::Vars;
use Mmsite::Lib::Subs;
use Net::Pface;

sub new {
    my ($class) = @_;
    my $self = bless {}, $class;
    
    # инициализируем экземпляр агента
    my $obj_pface = Net::Pface->new( id  => $AUTH_PFACE_ID, key => $AUTH_PFACE_KEY );
    warn "=> '$AUTH_PFACE_ID'";
    warn "=> '$AUTH_PFACE_KEY'";
    $self->{'PFACE'} = $obj_pface;

    return $self;
}

sub vk_get_user_name {
    # получаем две сессии и IP адрес и отдаем имя или ошибку
    my ( $self, $user_s1, $user_s2, $user_ip ) = @_;

    my $hash = $self->{'PFACE'}->auth( $user_s1, $user_s2, $user_ip );
    if ( exists $$hash{'result'} ) {
        my $lnk = $$hash{'result'};
        to_log( $PATH_LOG_PFACE, "PFACE", 'sucess: ' . $$lnk{'id'} . ', ' . $$lnk{'dname'} );
        return ( $$lnk{'dname'}, $$lnk{'id'} );
    }
    else {
        to_log( $PATH_LOG_PFACE, "PFACE", 'fail: ' . $$hash{'error'} );
        return ( 'error: ' .$$hash{'error'} );
    }
}

1;
