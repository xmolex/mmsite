package Mmsite::Lib::Vars;
#########################################################################################################
# модуль содержит настройки и общие функции широкого спектра
#########################################################################################################
use Modern::Perl;
use utf8;
use Encode;
use Fcntl qw(:DEFAULT :flock);
use Exporter 'import';

#########################################################################################################
# НАСТРОЙКИ
#########################################################################################################
our $DEBUG                     = 1; # включение / выключение дебага

our $DB_HOST                   = '127.0.0.1';                   # postgresql: server ip
our $DB_PORT                   = '5432';                        # postgresql: server port
our $DB_NAME                   = 'mmsite';                      # postgresql: database name
our $DB_USER                   = 'database';                    # postgresql: database user
our $DB_PASS                   = '';                            # postgresql: database password

our $AUTH_VK_VER               = '5.52';                        # vk.com версия API
our $AUTH_VK_ID                = '0000000';                     # vk.com идентификатор приложения
our $AUTH_VK_KEY               = '00000000000000000000';        # vk.com секретный ключ приложения

our $SITE_NAME                 = 'mmsite.ru';                   # сайт
our $PATH_ROOT                 = '/home/http/Mmsite/';          # путь к корневому каталогу
our $PATH_FFMPEG               = '/usr/local/bin/ffmpeg';       # путь к ffmpeg
our $PATH_FFPROBE              = '/usr/local/bin/ffprobe';      # путь к ffprobe из пакета ffmpeg
our $PATH_QTFASTSTART          = '/usr/local/bin/qt-faststart'; # путь к qt-faststart

our $PATH_SCRIPTS              = $PATH_ROOT.'scripts/';         # путь к каталогу со скриптами
our $PATH_LOGS                 = $PATH_ROOT.'logs/';            # путь к каталогу с логами
our $PATH_TEMPLATES            = $PATH_ROOT.'views/lib/';       # путь к каталогу с шаблонами для модулей
our $PATH_USERS                = $PATH_ROOT.'users/tmp/';       # путь к каталогу с пользовательскими директориями
our $PATH_TMP                  = $PATH_ROOT.'tmp/';             # путь к каталогу с временным содержимым
our $SITE_URL                  = 'http://'.$SITE_NAME.'/';      # корневой URL сайта
our $SITE_DATA_URL             = 'http://'.$SITE_NAME.'/';      # URL файлов

our $PATH_FILES                = $PATH_ROOT.'data/files/';      # путь к каталогу с файлами
our $PATH_FILES_IMG            = $PATH_ROOT.'data/files_img/';  # путь к каталогу с превьюшками для видео
our $PATH_FILES_SOURCE         = $PATH_ROOT.'data/files_sources/'; # путь к каталогу с исходниками для видео
our $PATH_POSTERS              = $PATH_ROOT.'data/posters/';    # путь к каталогу с постерами
our $PATH_SHOTS                = $PATH_ROOT.'data/shots/';      # путь к каталогу с кадрами
our $PATH_PHOTOS               = $PATH_ROOT.'data/photos/';     # путь к каталогу с фото

our $URL_FILES                 = $SITE_DATA_URL.'files/';       # url с файлами
our $URL_FILES_IMG             = $SITE_DATA_URL.'files_img/';   # url с превьюшками для видео
our $URL_POSTERS               = $SITE_DATA_URL.'posters/';     # url с постерами
our $URL_SHOTS                 = $SITE_DATA_URL.'shots/';       # url с кадрами
our $URL_PHOTOS                = $SITE_DATA_URL.'photos/';      # url с фото
our $URL_USERS_DATA            = $SITE_DATA_URL.'tmp/';         # url к каталогу, где хранятся временные файлы пользователей

our $URL_POSTERS_DEF           = $URL_POSTERS.'0.jpg';          # путь к постеру по умолчанию
our $URL_POSTERS_DEF_MINI      = $URL_POSTERS.'0_mini.jpg';     # путь к постеру по умолчанию (превью)
our $URL_PHOTOS_DEF            = $URL_PHOTOS.'0.jpg';           # путь к фото по умолчанию
our $URL_PHOTOS_DEF_MINI       = $URL_PHOTOS.'0_mini.jpg';      # путь к фото по умолчанию (превью)

our $IMG_SUF_ORIG              = '';                            # префикс к имени изображения (оригинал)
our $IMG_SUF_STD               = '_std_';                       # префикс к имени изображения
our $IMG_SUF_MINI              = '_mini_';                      # префикс к имени изображения (превью)

our $IMG_POSTER_X              = 200;                           # минимальная ширина для постеров
our $IMG_POSTER_Y              = 283;                           # минимальная высота для постеров
our $IMG_POSTER_MINI_X         = 120;                           # минимальная ширина для постеров (превью)
our $IMG_POSTER_MINI_Y         = 170;                           # минимальная высота для постеров (превью)
our $IMG_PHOTO_X               = 200;                           # минимальная ширина для фото
our $IMG_PHOTO_Y               = 283;                           # минимальная высота для фото
our $IMG_PHOTO_MINI_X          = 120;                           # минимальная ширина для фото (превью)
our $IMG_PHOTO_MINI_Y          = 170;                           # минимальная высота для фото (превью)
our $IMG_SHOT_X                = 350;                           # минимальная ширина для кадров
our $IMG_SHOT_Y                = 350;                           # минимальная высота для кадров
our $IMG_SHOT_MINI_X           = 100;                           # минимальная ширина для кадров (превью)
our $IMG_SHOT_MINI_Y           = 80;                            # минимальная высота для кадров (превью)
our $MAX_AUTO_SHOTS            = 8;                             # максимальное количество кадров для одного объекта группы при автоматической генерации

our $PATH_LOG_DB               = $PATH_LOGS.'/db.log';          # путь к логу базы данных
our $PATH_LOG_FFMPEG           = $PATH_LOGS.'/ffmpeg.log';      # путь к логу ffmpeg
our $PATH_LOG_VK               = $PATH_LOGS.'/vk.log';          # путь к логу ответов от vk.com

our $AUTH_COOKIE_PFACE_1       = 'pface_s1';                    # имя cookie для хранения первой сессии pface.ru
our $AUTH_COOKIE_PFACE_2       = 'pface_s2';                    # имя cookie для хранения второй сессии pface.ru
our $AUTH_COOKIE_VK_ID         = 'vkid';                        # имя cookie для хранения идентификатора пользователя vk.com
our $AUTH_COOKIE_VK_SESS       = 'vksess';                      # имя cookie для хранения сессии пользователя vk.com
our $AUTH_COOKIE_VK_FROM       = 'vkfrom';                      # имя cookie для хранения url перехода после авторизации

our $PLAYER_PLAYLIST_WIDTH     = 310;                           # размер по ширине отображения плейлиста в видеоплеере
our $PLAYER_TRAILER_WIDTH_MAX  = 300;                           # размер максимальной ширины трейлера
our $VIDEO_MAX_HEIGHT          = 800;                           # максимальный размер высоты видео. если будет больше, обязательно будет пережато
our $VIDEO_MAX_WIDTH           = 1280;                          # максимальный размер ширины видео. если будет больше, обязательно будет пережато
our $VIDEO_MAX_BITRATE         = 6000;                          # максимальный битрейт видео. если будет больше, обязательно будет пережато

our $COUNT_OBJECT_ANONCE       = 20;                            # количество выводимых анонсов объектов группы по умолчанию

our $KINOPOISK_URI_POSTER      = 'https://st.kp.yandex.net';    # uri адрес сервера kinopoisk.ru для постеров

our %LIST_GENRES = (
                  1750 => 'аниме',
                  22 => 'биография',
                  3 => 'боевик',
                  13 => 'вестерн',
                  19 => 'военный',
                  17 => 'детектив',
                  456 => 'детский',
                  20 => 'для взрослых',
                  12 => 'документальный',
                  8 => 'драма',
                  27 => 'игра',
                  23 => 'история',
                  6 => 'комедия',
                  1747 => 'концерт',
                  15 => 'короткометражка',
                  16 => 'криминал',
                  7 => 'мелодрама',
                  21 => 'музыка',
                  14 => 'мультфильм',
                  9 => 'мюзикл',
                  28 => 'новости',
                  10 => 'приключения',
                  25 => 'реальное ТВ',
                  11 => 'семейный',
                  24 => 'спорт',
                  26 => 'ток-шоу',
                  4 => 'триллер',
                  1 => 'ужасы',
                  2 => 'фантастика',
                  18 => 'фильм-нуар',
                  5 => 'фэнтези',
                  1751 => 'церемония'
);

our %LIST_COUNTRIES = (
                  25 => 'Австралия',
                  57 => 'Австрия',
                  136 => 'Азербайджан',
                  120 => 'Албания',
                  20 => 'Алжир',
                  1026 => 'Американские Виргинские острова',
                  1062 => 'Американское Самоа',
                  139 => 'Ангола',
                  159 => 'Андорра',
                  1044 => 'Антарктида',
                  1030 => 'Антигуа и Барбуда',
                  1009 => 'Антильские Острова',
                  24 => 'Аргентина',
                  89 => 'Армения',
                  175 => 'Аруба',
                  113 => 'Афганистан',
                  124 => 'Багамы',
                  75 => 'Бангладеш',
                  105 => 'Барбадос',
                  164 => 'Бахрейн',
                  69 => 'Беларусь',
                  173 => 'Белиз',
                  41 => 'Бельгия',
                  140 => 'Бенин',
                  109 => 'Берег Слоновой кости',
                  1004 => 'Бермуды',
                  148 => 'Бирма',
                  63 => 'Болгария',
                  118 => 'Боливия',
                  178 => 'Босния',
                  39 => 'Босния и Герцеговина',
                  145 => 'Ботсвана',
                  10 => 'Бразилия',
                  1066 => 'Бруней-Даруссалам',
                  92 => 'Буркина-Фасо',
                  162 => 'Бурунди',
                  114 => 'Бутан',
                  1059 => 'Вануату',
                  11 => 'Великобритания',
                  49 => 'Венгрия',
                  72 => 'Венесуэла',
                  1064 => 'Внешние малые острова США',
                  52 => 'Вьетнам',
                  170 => 'Вьетнам Северный',
                  127 => 'Габон',
                  99 => 'Гаити',
                  165 => 'Гайана',
                  1040 => 'Гамбия',
                  144 => 'Гана',
                  142 => 'Гваделупа',
                  135 => 'Гватемала',
                  129 => 'Гвинея',
                  116 => 'Гвинея-Бисау',
                  3 => 'Германия',
                  60 => 'Германия (ГДР)',
                  18 => 'Германия (ФРГ)',
                  1022 => 'Гибралтар',
                  112 => 'Гондурас',
                  28 => 'Гонконг',
                  1060 => 'Гренада',
                  117 => 'Гренландия',
                  55 => 'Греция',
                  61 => 'Грузия',
                  1045 => 'Гуам',
                  4 => 'Дания',
                  1037 => 'Демократическая Республика Конго',
                  1028 => 'Джибути',
                  1031 => 'Доминика',
                  128 => 'Доминикана',
                  101 => 'Египет',
                  155 => 'Заир',
                  133 => 'Замбия',
                  1043 => 'Западная Сахара',
                  104 => 'Зимбабве',
                  42 => 'Израиль',
                  29 => 'Индия',
                  73 => 'Индонезия',
                  154 => 'Иордания',
                  90 => 'Ирак',
                  48 => 'Иран',
                  38 => 'Ирландия',
                  37 => 'Исландия',
                  15 => 'Испания',
                  14 => 'Италия',
                  169 => 'Йемен',
                  146 => 'Кабо-Верде',
                  122 => 'Казахстан',
                  1051 => 'Каймановы острова',
                  84 => 'Камбоджа',
                  95 => 'Камерун',
                  6 => 'Канада',
                  1002 => 'Катар',
                  100 => 'Кения',
                  64 => 'Кипр',
                  1024 => 'Кирибати',
                  31 => 'Китай',
                  56 => 'Колумбия',
                  1058 => 'Коморы',
                  134 => 'Конго',
                  1014 => 'Конго (ДРК)',
                  156 => 'Корея',
                  137 => 'Корея Северная',
                  26 => 'Корея Южная',
                  1013 => 'Косово',
                  131 => 'Коста-Рика',
                  76 => 'Куба',
                  147 => 'Кувейт',
                  86 => 'Кыргызстан',
                  149 => 'Лаос',
                  54 => 'Латвия',
                  1015 => 'Лесото',
                  176 => 'Либерия',
                  97 => 'Ливан',
                  126 => 'Ливия',
                  123 => 'Литва',
                  125 => 'Лихтенштейн',
                  59 => 'Люксембург',
                  115 => 'Маврикий',
                  67 => 'Мавритания',
                  150 => 'Мадагаскар',
                  153 => 'Макао',
                  80 => 'Македония',
                  1025 => 'Малави',
                  83 => 'Малайзия',
                  151 => 'Мали',
                  1050 => 'Мальдивы',
                  111 => 'Мальта',
                  43 => 'Марокко',
                  102 => 'Мартиника',
                  1067 => 'Маршалловы острова',
                  1042 => 'Масаи',
                  17 => 'Мексика',
                  1041 => 'Мелкие отдаленные острова США',
                  81 => 'Мозамбик',
                  58 => 'Молдова',
                  22 => 'Монако',
                  132 => 'Монголия',
                  1065 => 'Монтсеррат',
                  1034 => 'Мьянма',
                  91 => 'Намибия',
                  106 => 'Непал',
                  157 => 'Нигер',
                  110 => 'Нигерия',
                  12 => 'Нидерланды',
                  138 => 'Никарагуа',
                  35 => 'Новая Зеландия',
                  1006 => 'Новая Каледония',
                  33 => 'Норвегия',
                  119 => 'ОАЭ',
                  1019 => 'Оккупированная Палестинская территория',
                  1003 => 'Оман',
                  1052 => 'Остров Мэн',
                  1047 => 'Остров Святой Елены',
                  1063 => 'Острова Кука',
                  1007 => 'острова Теркс и Кайкос',
                  74 => 'Пакистан',
                  1057 => 'Палау',
                  78 => 'Палестина',
                  107 => 'Панама',
                  163 => 'Папуа - Новая Гвинея',
                  143 => 'Парагвай',
                  23 => 'Перу',
                  32 => 'Польша',
                  36 => 'Португалия',
                  82 => 'Пуэрто Рико',
                  1036 => 'Реюньон',
                  1033 => 'Российская империя',
                  2 => 'Россия',
                  103 => 'Руанда',
                  46 => 'Румыния',
                  121 => 'Сальвадор',
                  1039 => 'Самоа',
                  1011 => 'Сан-Марино',
                  1072 => 'Сан-Томе и Принсипи',
                  158 => 'Саудовская Аравия',
                  1029 => 'Свазиленд',
                  1010 => 'Сейшельские острова',
                  65 => 'Сенегал',
                  1055 => 'Сент-Винсент и Гренадины',
                  1071 => 'Сент-Китс и Невис',
                  1049 => 'Сент-Люсия ',
                  177 => 'Сербия',
                  174 => 'Сербия и Черногория',
                  1021 => 'Сиам',
                  45 => 'Сингапур',
                  98 => 'Сирия',
                  94 => 'Словакия',
                  40 => 'Словения',
                  1069 => 'Соломоновы Острова',
                  160 => 'Сомали',
                  13 => 'СССР',
                  167 => 'Судан',
                  171 => 'Суринам',
                  1 => 'США',
                  1023 => 'Сьерра-Леоне',
                  70 => 'Таджикистан',
                  44 => 'Таиланд',
                  27 => 'Тайвань',
                  130 => 'Танзания',
                  1068 => 'Тимор-Лесте',
                  161 => 'Того',
                  1012 => 'Тонга',
                  88 => 'Тринидад и Тобаго',
                  1053 => 'Тувалу',
                  50 => 'Тунис',
                  152 => 'Туркменистан',
                  68 => 'Турция',
                  172 => 'Уганда',
                  71 => 'Узбекистан',
                  62 => 'Украина',
                  1073 => 'Уоллис и Футуна',
                  79 => 'Уругвай',
                  1008 => 'Фарерские острова',
                  1038 => 'Федеративные Штаты Микронезии',
                  166 => 'Фиджи',
                  47 => 'Филиппины',
                  7 => 'Финляндия',
                  8 => 'Франция',
                  1032 => 'Французская Гвиана',
                  1046 => 'Французская Полинезия',
                  85 => 'Хорватия',
                  141 => 'ЦАР',
                  77 => 'Чад',
                  1020 => 'Черногория',
                  34 => 'Чехия',
                  16 => 'Чехословакия',
                  51 => 'Чили',
                  21 => 'Швейцария',
                  5 => 'Швеция',
                  1070 => 'Шпицберген и Ян-Майен',
                  108 => 'Шри-Ланка',
                  96 => 'Эквадор',
                  1061 => 'Экваториальная Гвинея',
                  87 => 'Эритрея',
                  53 => 'Эстония',
                  168 => 'Эфиопия',
                  30 => 'ЮАР',
                  19 => 'Югославия',
                  66 => 'Югославия (ФР)',
                  93 => 'Ямайка',
                  9 => 'Япония'            
);

our %LIST_TRANSLATE = (
                  0 => 'Не требуется',
                  1 => 'Профессиональный (полное дублирование)',
                  2 => 'Профессиональный (многоголосый, закадровый)',
                  3 => 'Профессиональный (одноголосый)',
                  4 => 'Профессиональный (двухголосый)',
                  5 => 'Любительский (одноголосый)',
                  6 => 'Любительский (двухголосый)',
                  7 => 'Отсутствует'
);

our %ALLOW_AGE = (
                    0  => '0+',
                    6  => '6+',
                    12 => '12+',
                    16 => '16+',
                    18 => '18+'
);

#########################################################################################################

our @EXPORT = qw(
              $DEBUG
              $DB_HOST
              $DB_PORT
              $DB_NAME
              $DB_USER
              $DB_PASS
              $AUTH_VK_VER
              $AUTH_VK_ID 
              $AUTH_VK_KEY
              $SITE_NAME
              $PATH_ROOT
              $PATH_FFMPEG
              $PATH_FFPROBE
              $PATH_QTFASTSTART
              $PATH_SCRIPTS
              $PATH_LOGS
              $PATH_TEMPLATES
              $PATH_USERS
              $PATH_TMP
              $SITE_URL
              $SITE_DATA_URL
              $PATH_FILES
              $PATH_FILES_SOURCE
              $PATH_FILES_IMG
              $PATH_POSTERS
              $PATH_SHOTS
              $PATH_PHOTOS
              $URL_FILES
              $URL_FILES_IMG
              $URL_POSTERS
              $URL_SHOTS
              $URL_PHOTOS
              $URL_USERS_DATA
              $URL_POSTERS_DEF
              $URL_POSTERS_DEF_MINI
              $URL_PHOTOS_DEF
              $URL_PHOTOS_DEF_MINI
              $IMG_SUF_ORIG
              $IMG_SUF_STD
              $IMG_SUF_MINI
              $IMG_POSTER_X
              $IMG_POSTER_Y
              $IMG_POSTER_MINI_X
              $IMG_POSTER_MINI_Y
              $IMG_PHOTO_X
              $IMG_PHOTO_Y
              $IMG_PHOTO_MINI_X
              $IMG_PHOTO_MINI_Y
              $IMG_SHOT_X
              $IMG_SHOT_Y
              $IMG_SHOT_MINI_X
              $IMG_SHOT_MINI_Y
              $MAX_AUTO_SHOTS
              $PATH_LOG_DB
              $PATH_LOG_FFMPEG
              $PATH_LOG_VK
              $AUTH_COOKIE_PFACE_1
              $AUTH_COOKIE_PFACE_2
              $AUTH_COOKIE_VK_ID
              $AUTH_COOKIE_VK_SESS
              $AUTH_COOKIE_VK_FROM
              $PLAYER_PLAYLIST_WIDTH
              $PLAYER_TRAILER_WIDTH_MAX
              $VIDEO_MAX_HEIGHT
              $VIDEO_MAX_WIDTH
              $VIDEO_MAX_BITRATE
              $COUNT_OBJECT_ANONCE
              $KINOPOISK_URI_POSTER
              %LIST_GENRES
              %LIST_COUNTRIES
              %LIST_TRANSLATE
              %ALLOW_AGE
              &tr_sql
              &tr_html
              &get_sql_time
              &on_utf8
              &size_to_str
              &get_extension
              &convert_filename_to_latin
              &get_uniq_filename
              &is_running
            );

# получаем SQL команду и экранизируем опасности
sub tr_sql {
    my ($str) = @_;
    $str =~ s/'/''/gs;
    return $str;
}

# производим замены для принятых значений, которые должны пойти на вывод в html
sub tr_html {
    my ($str) = @_;
    $str =~ s/&/&amp;/gs;
    $str =~ s/</&lt;/gs;
    $str =~ s/>/&gt;/gs;
    $str =~ s/'/&apos;/gs;
    $str =~ s/"/&quot;/gs;
    return $str;
}

# формируем дату и время для базы данных, либо только дату (флаг вторым параметром)
# время можно передать в unix формате
sub get_sql_time {
    my $time = shift // time();
    my( $sec, $min, $hour, $mday, $mon, $year ) = localtime($time);
    $year = $year + 1900;
    $mon++;
    
    # добавляем ведущие нули
    $mon  = sprintf '%02d', $mon;
    $mday = sprintf '%02d', $mday;
    $hour = sprintf '%02d', $hour;
    $min  = sprintf '%02d', $min;
    $sec  = sprintf '%02d', $sec;
    
    if ($_[0]) {
        # запрос только на дату
        return "$year-$mon-$mday";
    }
    else {
        # запрос на дату и время
        return "$year-$mon-$mday $hour:$min:$sec";
    }
    
}

# функция выставляет флаг utf8 в on
# передаем ссылку на строку
sub on_utf8 {
    Encode::_utf8_on( ${ $_[0] } );
}

# получаем размер в байтах, а отдаем текстовую строку с удобным отображением
sub size_to_str {
    my ($size) = @_;

    # проверка на число
    return $size if $size !~ /^\d+$/;
    
    # высчитываем правильные значения
    if (! int($size / 1024 / 1024 / 1024) < 1 ) {
        # гигабайты
        $size = $size / 1024 / 1024 / 1024;
        return $size . '&nbsp;Gb' if $size - int($size) == 0;
        $size = sprintf '%0.2f', $size;
        return $size . '&nbsp;Gb';
    }
    
    elsif (! int($size / 1024 / 1024) < 1 ) {
        # мегабайты
        $size = $size / 1024 / 1024;
        return $size . '&nbsp;Mb' if $size - int($size) == 0;
        $size = sprintf '%0.2f', $size;
        return $size . '&nbsp;Mb';

    }
    
    elsif (! int($size / 1024) < 1 ) {
        # килобайты
        $size = $size / 1024;
        return $size . '&nbsp;Kb' if $size - int($size) == 0;
        $size = sprintf '%0.2f', $size;
        return $size . '&nbsp;Kb';
    }
    
    # байты
    return $size . '&nbsp;bytes';
}

# получаем имя или путь к файлу и отдаем расширение файла
sub get_extension {
    my ($str) = @_;
    
    my $extension;
    
    # если передали с unix путем, отделяем имя файла
    my $pos = rindex $str, '/';
    $str = substr($str, $pos + 1) if $pos != -1;
    
    # если передали с win путем, отделяем имя файла
    $pos = rindex $str, '\\';
    $str = substr($str, $pos + 1) if $pos != -1;
    
    # отделяем расширение
    $pos = rindex $str, '.';
    $extension = substr($str, $pos + 1) if $pos != -1;
    
    return $extension;
}

# переводим имя файла в латиницу
sub convert_filename_to_latin {
  my ($name) = @_;
  on_utf8(\$name);

  # замещаем
  $name =~ s/а/a/g;   $name =~ s/А/a/g; 
  $name =~ s/б/b/g;   $name =~ s/Б/b/g;
  $name =~ s/в/v/g;   $name =~ s/В/v/g;
  $name =~ s/г/g/g;   $name =~ s/Г/g/g;
  $name =~ s/д/d/g;   $name =~ s/Д/d/g;
  $name =~ s/е/e/g;   $name =~ s/Е/e/g;
  $name =~ s/ё/jo/g;  $name =~ s/Ё/jo/g;
  $name =~ s/ж/zh/g;  $name =~ s/Ж/zh/g;
  $name =~ s/з/z/g;   $name =~ s/З/z/g;
  $name =~ s/и/i/g;   $name =~ s/И/i/g;
  $name =~ s/й/j/g;   $name =~ s/Й/j/g;
  $name =~ s/к/k/g;   $name =~ s/К/k/g;
  $name =~ s/л/l/g;   $name =~ s/Л/l/g;
  $name =~ s/м/m/g;   $name =~ s/М/m/g;
  $name =~ s/н/n/g;   $name =~ s/Н/n/g;
  $name =~ s/о/o/g;   $name =~ s/О/o/g;
  $name =~ s/п/p/g;   $name =~ s/П/p/g;
  $name =~ s/р/r/g;   $name =~ s/Р/r/g;
  $name =~ s/с/s/g;   $name =~ s/С/s/g;
  $name =~ s/т/t/g;   $name =~ s/Т/t/g;
  $name =~ s/у/u/g;   $name =~ s/У/u/g;
  $name =~ s/ф/f/g;   $name =~ s/Ф/f/g;
  $name =~ s/х/kh/g;  $name =~ s/Х/kh/g;
  $name =~ s/ц/c/g;   $name =~ s/Ц/c/g;
  $name =~ s/ч/ch/g;  $name =~ s/Ч/ch/g;
  $name =~ s/ш/sh/g;  $name =~ s/Ш/sh/g;
  $name =~ s/щ/shh/g; $name =~ s/Щ/shh/g;
  $name =~ s/ъ//g;    $name =~ s/Ъ//g;
  $name =~ s/ы/y/g;   $name =~ s/Ы/y/g;
  $name =~ s/ь//g;    $name =~ s/Ь//g;
  $name =~ s/э/eh/g;  $name =~ s/Э/eh/g;
  $name =~ s/ю/ju/g;  $name =~ s/Ю/ju/g;
  $name =~ s/я/ja/g;  $name =~ s/Я/ja/g;
  $name =~ s/\s/_/g;

  # собираем имя из безопасных символов
  $name = join "", grep { /[\w\.\_\-]/i } split //, $name;
  
  return($name);
}

# функция формирования случайного имени для файла
sub get_uniq_filename {
   my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime();
   my $name = $sec + $min * 60 + $hour * 3600 + $mday * 86400 + $mon * 2678400 + $year * 977616000;
   $name .= int( rand(999) );
   return $name;
}

# функция проверки запуска копии скрипта
sub is_running {
    my ($pidfile) = @_;
    my $result;

    sysopen LOCK, $pidfile, O_RDWR|O_CREAT or die "Невозможно открыть файл $pidfile: $!";

    # пытаемся заблокировать файл
    if ( flock LOCK, LOCK_EX|LOCK_NB  ) {
        # блокировака удалась, поэтому запишем в файл наш идентификатор процесса
        truncate LOCK, 0 or warn "Невозможно усечь файл $pidfile: $!";
        my $old_fh = select LOCK;
        $| = 1;
        select $old_fh;
        print LOCK $$;
        # оставим файл открытым и заблокированным
    }
    else {
        # заблокировать не удалось, т.к. кто-то уже заблокировал файл
        $result = <LOCK>;

        # получим идентификатор процесса
        if (defined $result) {
            chomp $result;
        }
        else {
            warn "Отсутствует PID в пид-файле $pidfile";
            $result = 'block';
        }
    }

    return $result;
}

1;

