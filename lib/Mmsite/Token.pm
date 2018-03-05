######################################################################################
# модуль для отображения информации выполнения продолжительных по времени задач
######################################################################################
package Mmsite::Token;
use Dancer2 appname => 'Mmsite';
use Modern::Perl;
use utf8;
use Mmsite::Lib::Vars;
use Mmsite::Lib::Token;

prefix '/token';

post '' => sub {
   
    my $token = body_parameters->get('token');
    return '{"error": "empty token"}' unless $token;
    
    my %hash;
    
    # выводим информацию о текущем статусе задачи
        
    my $obj_token = Mmsite::Lib::Token->new($token);
    return '{"error": "do not create token object"}' unless $obj_token;
        
    my ( $value, $complete ) = $obj_token->get();

    if ($complete) {
        # задача выполнена
        
        if ($value =~ m!^error:!) {
            # возникли ошибки
            $hash{'error'} = $value;
        }
        else {
            # выполнилось успешно
            $hash{'result'} = $value;
        }

    }
    else {
        # задача в процессе выполнения
        $hash{'process'} = $value;
    }
        
    # формируем json и отдаем
    my $json = to_json \%hash;
    on_utf8(\$json);
    return $json;
};

1;