package Mmsite::Lib::Members;
################################################################################
#  Управление пользователями
################################################################################
use Modern::Perl;
use utf8;
use Mmsite::Lib::Vars;
use Mmsite::Lib::Db;
use parent 'Mmsite::Lib::Members::Auth';
use parent 'Mmsite::Lib::Members::Subscribe';
use parent 'Mmsite::Lib::Members::View';

sub new {
    my $class = shift;
    my $obj = bless {}, $class;
    $obj->auth();
    return $obj;
}

# аксессоры
sub id          { return shift->{id}; }
sub name        { return shift->{name}; }
sub role        { return shift->{role}; }
sub auth_sys    { return shift->{auth_sys}; }
sub auth_sys_id { return shift->{auth_sys_id}; }

1;
