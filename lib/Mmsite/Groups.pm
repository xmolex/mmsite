######################################################################################
# вывод информации об объекте группы
######################################################################################
package Mmsite::Groups;
use Dancer2 appname => 'Mmsite';
use Modern::Perl;
use utf8;
use Mmsite::Lib::Vars;
use Mmsite::Lib::Auth;

prefix '/groups';

# выводим информацию о группе
any '/:group_id' => sub {

    my $group_id = route_parameters->get('group_id');
    redirect '/' if $group_id !~ m/^\d+$/;

    my $obj = Mmsite::Lib::Groups->new($group_id);
    redirect '/' unless $obj;
    
    # авторизация
    my ( $user_id, $user_name, $user_role, $user_sys, $users_sys_id ) = Auth();  
    
    $obj->get();
    # жанры
    my $genres = '';
    $genres .= $LIST_GENRES{$_} . ', ' foreach ( @{ $obj->genres } );
    $genres =~ s/,\s$//;
    # страны
    my $countries = '';
    $countries .= $LIST_COUNTRIES{$_} . ', ' foreach ( @{ $obj->countries } );
    $countries =~ s/,\s$//;
    
    # постер
    my $poster_title = $obj->title;
    my $poster_url   = $URL_POSTERS_DEF;
    my @poster = $obj->get_images('poster'); # [ id, title, url_preview, url, url_orig ]
    if ($poster[0]) {
        $poster_title = $poster[1];
        $poster_url   = $poster[3];
    }
    
    # кадры
    my $shots;
    my @shots = $obj->get_images('shots'); # [ id, title, url_preview, url, url_orig ]
    if ($shots[0]) {
        # заносим в правильную структуру
        for ( my $i=0; $i<scalar(@shots); $i=$i+5 ) {
            my $data = {
                          title    => $shots[$i+1],
                          url      => $shots[$i+3],
                          url_orig => $shots[$i+4]
            };
            push @$shots, $data;
        }
    }
    
    # трейлеры
    my $trailers;
    my @trailers = $obj->get_files('trailers'); # [ id, title, file, size, res_x, res_y ]
    if ($trailers[0]) {
        # заносим в правильную структуру
        

        
        # проходимся по всем трейлерам и собираем структуру для вывода
        for ( my $i=0; $i<scalar(@trailers); $i=$i+6 ) {
            # рассчитываем разрешение для трейлера
            if ($trailers[$i+4] > $PLAYER_TRAILER_WIDTH_MAX && $trailers[$i+4]) {
                $trailers[$i+5] = int( $trailers[$i+5] * ($PLAYER_TRAILER_WIDTH_MAX / $trailers[$i+4]) ); # высота
                $trailers[$i+4] = $PLAYER_TRAILER_WIDTH_MAX; # ширина
            }

            # структура
            my $data = {
                          id    => $trailers[$i],
                          title => $trailers[$i+1],
                          url   => $URL_FILES . $trailers[$i+2],
                          size  => $trailers[$i+3],
                          res_x => $trailers[$i+4],
                          res_y => $trailers[$i+5],
                          image => $URL_FILES_IMG . $trailers[$i] . '.jpg'
            };
            push @$trailers, $data;
        }
    }
    
    # проверка на доступ просмотра
    my $allow_show = 1;
 
    # выводим
    template 'group_info' => {
                                'id'           => $group_id,
                                'allow_show'   => $allow_show,
                                'poster_url'   => $poster_url,
                                'poster_title' => $poster_title,
                                'title'        => $obj->title,
                                'title_orig'   => $obj->title_orig,
                                'description'  => $obj->description,
                                'year'         => $obj->year,
                                'allow_age'    => $obj->allow_age,
                                'rate_our'     => $obj->rate_our,
                                'is_serial'    => $obj->is_serial,
                                'genres'       => $genres,
                                'countries'    => $countries,
                                'shots'        => $shots,
                                'trailers'     => $trailers,
                                'user_role'    => $user_role
                             };
};

1;
