######################################################################################
# поиск объектов групп по заданным фильтрам
######################################################################################
package Mmsite::Search;
################################################################################
# настройки
################################################################################
my $SUF_SEARCH = 'search_'; # суффикс ключа memcached для сохраненных результатов поиска
################################################################################

use Dancer2 appname => 'Mmsite';
use Modern::Perl;
use utf8;
use Encode;
use Mmsite::Lib::Vars;
use Mmsite::Lib::Db;
use Mmsite::Lib::Mem;
use Mmsite::Lib::Groups;

prefix '/search';

# ищем идентификаторы, удовлетворяющие условиям: #название, #год, #жанр, #страна, #многосерийность
post '' => sub {

    # получаем токен
    my $token = body_parameters->get('token');
    return '{"error" : "token is empty"}' unless $token;

    # получаем фильтры
    my $text    = body_parameters->get('text');
    my $year    = body_parameters->get('year');
    my $genre   = body_parameters->get('genre');
    my $country = body_parameters->get('country');
    my $serial  = body_parameters->get('serial');
    
    # получаем номер страницы
    my $page = body_parameters->get('page') || 1;
    unless ($page =~ m/^\d+$/) {$page = 1;}
    if ($page < 1) {$page = 1;}
    
    # объявляем результирующий массив
    my @result;
    
    # проверяем был ли уже поиск, пытаясь получить данные из кэша
    my $json_decode;
    my $key = $SUF_SEARCH . $token;
    my $memcached = mem_get()->get($key);
    if ($memcached) {
        # данные есть, распарсиваем
        $memcached = Encode::encode_utf8($memcached);
        if ( eval { $json_decode = from_json $memcached } ) {
            # удалось распарсить @$json_decode
            @result = @$json_decode;
        }
    }
    else {
        # данных не было, необходимо произвести поиск в базе
        
        # проверяем полученное
    
        # строка
        # вырезаем и экранируем опасные символы
        if ( defined $text ) {
            $text = tr_sql($text);
            $text =~ s!%!!g;
        }
    
        # год
        if ( defined $year ) {
            return '{"error" : "wrong year"}' if $year !~ m/^\d{4}$/;
        }
    
        # жанр
        if ( defined $genre ) {
            my $is = 0;
            foreach (keys %LIST_GENRES) {
                if ($_ == $genre) {
                    # найден
                    $is = 1;
                    last;
                }
            }
            $is = 1 if $genre == 0; # все жанры
            return '{"error" : "wrong genre"}' unless $is;
        }
    
        # страна
        if ( defined $country ) {
            my $is = 0;
            foreach (keys %LIST_COUNTRIES) {
                if ($_ == $country) {
                    # найден
                    $is = 1;
                    last;
                }
            }
            return '{"error" : "wrong country"}' unless $is;
        }
    
        # многосерийность не проверяем, т.к. проверка будет позднее в условиях
        # -1:фильм, 0:фильтра нет, 1:сериал
    
        # собираем запрос
        my $sql = 'SELECT group_id FROM groups_list';
    
        if ( $text || $year || $genre || $country || $serial ) {$sql .= " WHERE";}

    
        if ($text) {
            $sql .= " group_id IN (SELECT id FROM groups_data WHERE ( title ILIKE '%$text%' OR title_orig ILIKE '%$text%' ))";
            if ( $year || $genre || $country || $serial ) {$sql .= " AND";}
        }

        if ($year) {
            $sql .= " group_id IN (SELECT id FROM groups_data WHERE year='$year')";
            if ( $genre || $country || $serial ) {$sql .= " AND";}
        }

        if ($serial) {
            if ($serial eq '-1') {
                $sql .= " group_id IN (SELECT id FROM groups_data WHERE AND is_serial=FALSE)";
            }
            else {
                $sql .= " group_id IN (SELECT id FROM groups_data WHERE AND is_serial=TRUE)";
            }
            if ( $genre || $country ) {$sql .= " AND";}
        }
    
        if ($genre) {
            $sql .= " group_id IN (SELECT group_id FROM groups_genres WHERE genres_id='$genre')";
            if ( $country ) {$sql .= " AND";}
        }

        if ($country) {$sql .= " group_id IN (SELECT group_id FROM groups_countries WHERE countries_id='$country')";}
    
        $sql .= " ORDER BY id DESC;";
    
        # выполняем запрос
        $sql = sql($sql);
        
        @result = @$sql;
        
        # сохраняем в кеше на 1 час
        $memcached = to_json \@result;
        mem_get()->delete($key);
        mem_get()->add( $key, $memcached, 3600 );
    }
    
    # на текущий момент у нас должнен быть массив из идентификаторов объектов группы
    
    # проверяем, а есть ли что выводить
    return '{"result" : "ничего не найдено"}' if ( scalar(@result) == 0 );
    
    # в $COUNT_OBJECT_ANONCE у нас количество которое нужно вывести на одной странице
    # если оно превышает общее количество элементов, то нужно его уменьшить
    my $count_objects = $COUNT_OBJECT_ANONCE;
    if ( $count_objects > scalar @result ) {
        $count_objects = scalar @result;
    }
    
    # рассчитываем смещение
    my $offset = 0;
    if ($page > 1) {$offset = $count_objects * --$page;}
    
    # проходимся по этому массиву и собираем превьюшки всех объектов группы
    my $all_html_result = '';
    
    for my $i ( $offset .. $offset + $count_objects ) {
    
        next unless defined $result[$i]; # если ничего нет, то проверяем слудующий элемент
    
        # получаем код анонса объекта группы
        my $obj_group = Mmsite::Lib::Groups->new($result[$i]);
        $all_html_result .= $obj_group->preview() if $obj_group;
    }
    
    # формируем json
    my %hash;
    $hash{'result'} = $all_html_result;
    my $result = to_json \%hash;
    on_utf8(\$result);
    
    # возвращаем json
    return $result;
};

1;
