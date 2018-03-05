#################################################################
#  работа с kinopoisk.ru
#################################################################
package Mmsite::Lib::Kinopoisk;

use Modern::Perl;
use LWP 5.64;
use HTTP::Cookies;
use Mmsite::Lib::Vars;

use constant DOWNLOAD_AGENT => 'Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0; .NET CLR 2.0.50727; .NET CLR 3.0.4506.2152; .NET CLR 3.5.30729; .NET4.0C)';
use constant HTTP_REFERER   => 'https://kinopoisk.ru';
use constant HTTP_ACCEPT    => 'text/html, */*;q=0.1';

use constant URI_CAPTCHA    => 'https://www.kinopoisk.ru/checkcaptcha'; # uri к странице kinopoisk.ru с проверкой капчи
use constant URI_FILM       => 'https://www.kinopoisk.ru/film';         # uri к странице kinopoisk.ru с информацией о фильме

# объявляем переменные браузера
my $browser = LWP::UserAgent->new;
$browser->agent( DOWNLOAD_AGENT );
my $cookie_jar = HTTP::Cookies->new( file => "$PATH_TMP/cookies_kinopoisk.txt", autosave => 1 );
$browser->cookie_jar($cookie_jar);

my %OBJECTS;

sub new {
    my ( $class, $cinema_id ) = @_;
    
    # реализуем singleton
    return $OBJECTS{$cinema_id} if $OBJECTS{$cinema_id};
    
    # проверка на числовое значение
    return unless ( _check_cinema_id($cinema_id) );
    
    my $self = {
                  'id' => $cinema_id
    };
    
    # возвращаем объект
    $OBJECTS{$cinema_id} = bless $self, $class;
    return $OBJECTS{$cinema_id};
}

# собираем информацию со странички с фильмом
sub get {
    my ( $self ) = @_;
        
    # проверяем, а не нужно ли нам отправить капчу
    if ( $self->{'captcha_need'} ) {
        # нужно, проверяем, а все ли данные у нас есть
        if ( $self->{'captcha_key'} && $self->{'captcha_retpath'} && $self->{'captcha_rep'} ) {
            # есть все данные, отправляем методом GET (нак на kinopoisk.ru реализовано)
            my $req = HTTP::Request->new( GET => URI_CAPTCHA . '?key=' . $self->{'captcha_key'} . '&retpath=' . $self->{'captcha_retpath'} . '&rep=' . $self->{'captcha_rep'} );
            $req->header( Accept => HTTP_ACCEPT, referer => HTTP_REFERER );
            my $response = $browser->request($req);
            my $data = $response->decoded_content;
            on_utf8(\$data);
            
            $self->{'captcha_need'} = 0;
            $self->{'html'} = $data;
        }

    }
    else {
        # запроса на капчу нет, обращаемся на страницу фильма
        my $req = HTTP::Request->new( GET => URI_FILM . '/' . $self->{'id'} . '/' );
        $req->header( Accept => HTTP_ACCEPT, referer => HTTP_REFERER );
        my $response = $browser->request($req);
        my $data = $response->decoded_content;
        on_utf8(\$data);
    
        $self->{'html'} = $data;
    
        # проверяем, не попросили ли у нас капчу
        if ( $self->_need_captcha() ) {
            # нас посчитали роботом и просят ввести капчу
            my ( $result, $lnk ) = $self->_parse_captcha_page();
            return( 0, $lnk ) unless $result;
        
            # указываем данные и выходим, т.к. без капчи нам делать нечего
            $self->{'captcha_need'}    = 1;
            $self->{'captcha_img'}     = $$lnk{'img'};
            $self->{'captcha_key'}     = $$lnk{'key'};
            $self->{'captcha_retpath'} = $$lnk{'retpath'};
            return 1;
        }
            
    }
        
    
    # если мы дошли до этого шага, значит у нас есть html страницы с фильмом и мы можем парсить
    $self->{'html'} =~ s/\n//g;
        
    # название и многосерийность
    if ( $self->{'html'} =~ m!<h1.+?itemprop="name">(.+?)</h1>! ) {
        $self->{'title'} = $1;
        
        # проверка на многосерийность
        if ($self->{'title'} =~ m!<span.+?episodes.+?</span>!) {
            $self->{'title'} = substr( $self->{'title'}, 0, index( $self->{'title'}, '<span') );
            $self->{'title'} =~ s/\s+$//;
            $self->{'is_serial'} = 1;
        }
        else {
            $self->{'is_serial'} = 0;
        }
    }
        
    # оригинальное название
    if ( $self->{'html'} =~ m!<span itemprop="alternativeHeadline">(.+?)</span>! ) {
        $self->{'title_orig'} = $1;
        # если попал мусор, значит данных нет
        if ($self->{'title_orig'} =~ /[<>]+/) {$self->{'title_orig'} = '';}
    }
        
    # описание
    if ( $self->{'html'} =~ m!<meta itemprop="description" content="(.+?)"! ) {
        $self->{'description'} = $1;
    }

    # год
    my $str = '<td class="type">год</td>'; on_utf8(\$str);
    $self->{'year'} = $self->{'html'};
    my $pos = index($self->{'year'}, $str);
    if ($pos != -1) {
        $self->{'year'} = substr( $self->{'year'}, $pos + length($str) );
        if ( $self->{'year'} =~ m!>(\d{4})</a>! ) {
            $self->{'year'} = $1;
        }
        else {
            $self->{'year'} = '';
        }
    }
    else {
        # ничего не нашли
        $self->{'year'} = '';
    }

    # жанры
    if ( $self->{'html'} =~ m!<span itemprop="genre">(.+?)</span>! ) {
        $self->{'genres'} = $1;
        my @genres;
        while ($self->{'genres'} =~ s!<a.+?(\d+)/">!!) {
           push @genres, $1;
        }
        $self->{'genres'} = \@genres;
    }
        
    # страны
    $str = '<td class="type">страна</td>'; on_utf8(\$str);
    $self->{'countries'} = $self->{'html'};
    $pos = index($self->{'countries'}, $str);
    if ($pos != -1) {
        $self->{'countries'} = substr( $self->{'countries'}, $pos + length($str) );
        $self->{'countries'} = substr( $self->{'countries'}, 0, index($self->{'countries'}, '</td>') );
        $self->{'countries'} = substr( $self->{'countries'}, index($self->{'countries'}, '<a') );
        $self->{'countries'} = substr( $self->{'countries'}, 0, rindex($self->{'countries'}, 'a>') + 2 );
        my @countries;
        while ( $self->{'countries'} =~ s!<a.+?(\d+)/">!! ) {
           push @countries, $1;
        }
        $self->{'countries'} = \@countries;
    }
    else {
        # ничего не нашли
        $self->{'countries'} = '';
    }
    
    # постер
    if ( $self->{'html'} =~ m!<a class="popupBigImage".+?'(.+?)'! ) {
        $self->{'poster'} = $1;
    }
    
    # разрешенный возраст просмотра
    if ( $self->{'html'} =~ m!<div class="ageLimit age(\d+)"></div>! ) {
        $self->{'allow_age'} = $1;
    }
    
    return 1;
}

# устанавливаем свойства, без какой-либо внешней модификации 
sub set {
    my ( $self, $key, $value ) = @_;
    return unless $key;
    $self->{$key} = $value;
    return 1;
}

# получаем url постера на кинопоиске, скачиваем и сохраняем его по указанному пути
# работаем без объекта
sub download_poster {
    my ( $url, $path_file ) = @_;

    # проверяем ссылку
    return( 0, "ссылка не ведет на сайт кинопоиска" ) if ( index( $url, $KINOPOISK_URI_POSTER ) != 0 );
    
    # если файл есть, то удалим его
    unlink($path_file) if (-f $path_file);
    
    # скачиваем
    my $response = $browser->mirror( $url, $path_file );
    if ( $response->{_rc} >= 200 && $response->{_rc} <= 299 ) {
        return 1;
    }
    else {
        return( 0, "не удалось скачать: $response->{_rc}" );
    }
}


# аксессоры
sub id              { return shift->{id}; }
sub html            { return shift->{html}; }
sub captcha_need    { return shift->{captcha_need}; }
sub captcha_key     { return shift->{captcha_key}; }
sub captcha_retpath { return shift->{captcha_retpath}; }
sub captcha_rep     { return shift->{captcha_rep}; }
sub captcha_img     { return shift->{captcha_img}; }
sub title           { return shift->{title}; }
sub is_serial       { return shift->{is_serial}; }
sub title_orig      { return shift->{title_orig}; }
sub description     { return shift->{description}; }
sub year            { return shift->{year}; }
sub genres          { return shift->{genres}; }
sub countries       { return shift->{countries}; }
sub poster          { return shift->{poster}; }
sub allow_age       { return shift->{allow_age}; }


# локальные функции
# локально: проверка на идентификатор фильма
sub _check_cinema_id {
    if ($_[0] !~ m/^\d+$/) {return();} else {return(1);}
}

# локально: проверка на требование капчи
sub _need_captcha {
    my ($self) = @_;
    return 1 if $self->{'html'} =~ m/captcha/; # есть требование ввести капчу
    return;
}

# локально: парсим страницу с капчей
# возвращаем результат (булево), структуру для отправки формы
sub _parse_captcha_page {
    my ($self) = @_;

    my %captcha_form;
    
    return( 0, 'не удалось определить страницу с изображением капчи' ) unless $self->{'html'} =~ m!"(https://www.kinopoisk.ru/captchaimg.+?)"!;
    
    $captcha_form{'img'} = $1;
    
    return( 0, 'не удалось определить шифрованную сессию для отправки формы' ) unless $self->{'html'} =~ m/<input.+?name="key".+?value="(.+?)"/;
    
    $captcha_form{'key'} = $1;
    
    return( 0, 'не удалось определить адрес перехода для отправки формы' ) unless $self->{'html'} =~ m/<input.+?name="retpath".+?value="(.+?)"/;
    
    $captcha_form{'retpath'} = $1;
    
    return( 1, \%captcha_form );
}



1;