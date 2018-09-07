package Mmsite::Search;
######################################################################################
# поиск объектов групп по заданным фильтрам
######################################################################################
# настройки
######################################################################################
my $SUF_SEARCH = 'search_'; # суффикс ключа memcached для сохраненных результатов поиска
######################################################################################
use Dancer2 appname => 'Mmsite';
use Modern::Perl;
use utf8;
use Encode;
use Mmsite::Lib::Vars;
use Mmsite::Lib::Subs;
use Mmsite::Lib::Db;
use Mmsite::Lib::Mem;
use Mmsite::Lib::Groups;
use Mmsite::Lib::Members;

prefix '/search';

# ищем идентификаторы, удовлетворяющие условиям: #название, #год, #жанр, #страна, #многосерийность
post '' => sub {

    # авторизация
    my $member_obj = Mmsite::Lib::Members->new();

    # получаем токен
    my $token = body_parameters->get('token');
    return '{"error" : "token is empty"}' unless $token;

    # получаем фильтры
    my $text    = body_parameters->get('text');
    my $year    = body_parameters->get('year');
    my $genre   = body_parameters->get('genre');
    my $country = body_parameters->get('country');
    my $type    = body_parameters->get('type');
    
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
        if ( defined $year && $year ) {
            return '{"error" : "wrong year"}' if $year !~ m/^\d{4}$/;
        }
    
        # жанр
        if ( defined $genre && $genre ) {
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
        if ( defined $country && $country ) {
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
    
        # тип не проверяем, т.к. проверка будет позднее в условиях
        # -1:фильм, 0:фильтра нет, 1:сериал, 2:подписки
    
        # собираем запрос
        my $sql = 'SELECT group_id FROM groups_list';
    
        if ( $text || $year || $genre || $country || $type ) {$sql .= " WHERE";}

    
        if ($text) {
            $sql .= " group_id IN (SELECT id FROM groups_data WHERE ( title ILIKE '%$text%' OR title_orig ILIKE '%$text%' ))";
            if ( $year || $genre || $country || $type ) {$sql .= " AND";}
        }

        if ($year) {
            $sql .= " group_id IN (SELECT id FROM groups_data WHERE year='$year')";
            if ( $genre || $country || $type ) {$sql .= " AND";}
        }

        if ($type) {
            if ($type eq '2') {
                # вывести подписки
                $sql .= " group_id IN (SELECT group_id FROM member_subscribes WHERE member_id='" . $member_obj->id . "')";
            }
            elsif ($type eq '-1') {
                $sql .= " group_id IN (SELECT id FROM groups_data WHERE is_serial=FALSE)";
            }
            else {
                $sql .= " group_id IN (SELECT id FROM groups_data WHERE is_serial=TRUE)";
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
    return '{"result" : "Ничего не нашлось"}' if ( scalar(@result) == 0 );
    
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
    
    for my $i ( $offset .. $offset + $count_objects - 1 ) {
    
        next unless defined $result[$i]; # если ничего нет, то проверяем слудующий элемент
    
        # получаем код анонса объекта группы
        my $obj_group = Mmsite::Lib::Groups->new($result[$i]); 
        if ($obj_group) {
            my $tmp = $obj_group->preview();
            
            # проверка на подписку и непросмотренные файлы
            if ( $member_obj->is_subscribe($obj_group->id) ) {
                if ( $member_obj->is_view_unlooked($obj_group->id) ) {
                    $tmp =~ s/"gf-anc-one"/"gf-anc-one-unlooked"/s;
                }
            }

            $all_html_result .= $tmp;
        }
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
