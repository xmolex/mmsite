package Mmsite::Lib::Token;
#################################################################
#  Управление токенами продолжительных задач
#################################################################
use Modern::Perl;
use utf8;
use Mmsite::Lib::Vars;
use Mmsite::Lib::Subs;
use Mmsite::Lib::Db;

# объявляем токен
sub new {
    my ( $class, $token ) = @_;

    # проверка на допустимый идентификатор
    return unless ( _check_token($token) );
    
    # проверяем, есть ли у нас такой токен
    my $sql = sql("SELECT id FROM target_sessions WHERE id='$token';");
    unless ($$sql[0]) {
        # добавляем в базу
        unless ( sql( "INSERT INTO target_sessions (id,value,last_modify) VALUES ('$token','Инициализация'," . time() . ");", 1 ) ) {
            # не удалось
            return;
        }
    }

    # создаем объект
    my $self = { id => $token };
    bless $self, $class;
}

# получаем свойства объекта группы, возвращаем значение
sub get {
    my ($self) = @_;
    my $sql = sql("SELECT value,complete FROM target_sessions WHERE id = '$self->{'id'}';");
    return( $$sql[0], $$sql[1] );    
}

# метод изменения объекта файла
sub set {
    my ( $self, $value, $complete ) = @_;
    
    $value = tr_sql $value;
    
    if ($complete) {
        $complete = 'TRUE';
    }
    else {
        $complete = 'FALSE';
    }
    
    # ставим
    if ( sql( "UPDATE target_sessions SET value = '$value', last_modify = " . time() . ", complete=$complete WHERE id = '$self->{'id'}';", 1 ) ) {
        # поменяли
        return 1; 
    }
    
    # не удалось установить
    return;
}

# удаление
# возвращаем булево
sub delete {
    my ($self) = @_;

    # удаляем
    if ( sql( "DELETE FROM target_sessions WHERE id='$self->{'id'}';", 1 ) ) {
        return 1;
    }

    return;
}

# локально: проверка на идентификатор
sub _check_token {
    my ($token) = @_;
    return if $token !~ m!^\w+$!;
    return 1;
}

1;
