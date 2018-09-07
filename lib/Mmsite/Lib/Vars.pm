package Mmsite::Lib::Vars;
#########################################################################################################
# модуль содержит настройки и общие функции широкого спектра
#########################################################################################################
# НАСТРОЙКИ
#########################################################################################################
my $config_path = '/usr/home/http/Mmsite/config.yml'; # путь к yaml конфигу
#########################################################################################################
use Modern::Perl;
use utf8;
use Exporter 'import';
use YAML;

my $yml;
open my $fh, '<', $config_path;
die "Don't open YAML config file $config_path: $!" unless $fh;
$yml .= $_ for(<$fh>);
close $fh;

my $config = YAML::Load($yml);

our $DEBUG                     = $config->{'DEBUG'}                    // 0;

our $DB_HOST                   = $config->{'DB_HOST'}                  // '127.0.0.1';
our $DB_PORT                   = $config->{'DB_PORT'}                  // '5432';
our $DB_NAME                   = $config->{'DB_NAME'}                  // 'mmsite';
our $DB_USER                   = $config->{'DB_USER'}                  // 'database';
our $DB_PASS                   = $config->{'DB_PASS'}                  // '';

our $AUTH_VK_VER               = $config->{'AUTH_VK_VER'}              // '';
our $AUTH_VK_ID                = $config->{'AUTH_VK_ID'}               // '';
our $AUTH_VK_KEY               = $config->{'AUTH_VK_KEY'}              // '';

our $AUTH_PFACE_ID             = $config->{'AUTH_PFACE_ID'}            // '';
our $AUTH_PFACE_KEY            = $config->{'AUTH_PFACE_KEY'}           // '';

our $SITE_NAME                 = $config->{'SITE_NAME'}                // 'localhost';
our $PATH_ROOT                 = $config->{'PATH_ROOT'}                // '/home/http/Mmsite/';
our $PATH_FFMPEG               = $config->{'PATH_FFMPEG'}              // '/usr/local/bin/ffmpeg';
our $PATH_FFPROBE              = $config->{'PATH_FFPROBE'}             // '/usr/local/bin/ffprobe';
our $PATH_QTFASTSTART          = $config->{'PATH_QTFASTSTART'}         // '/usr/local/bin/qt-faststart';

our $PATH_SCRIPTS              = $config->{'PATH_SCRIPTS'}             // $PATH_ROOT.'scripts/';
our $PATH_LOGS                 = $config->{'PATH_LOGS'}                // $PATH_ROOT.'logs/';
our $PATH_TEMPLATES            = $config->{'PATH_TEMPLATES'}           // $PATH_ROOT.'views/lib/';
our $PATH_USERS                = $config->{'PATH_USERS'}               // $PATH_ROOT.'users/tmp/';
our $PATH_TMP                  = $config->{'PATH_TMP'}                 // $PATH_ROOT.'tmp/';
our $SITE_URL                  = $config->{'SITE_URL'}                 // 'http://'.$SITE_NAME.'/';
our $SITE_DATA_URL             = $config->{'SITE_DATA_URL'}            // 'http://'.$SITE_NAME.'/';

our $PATH_FILES                = $config->{'PATH_FILES'}               // $PATH_ROOT.'data/files_web/';
our $PATH_FILES_IMG            = $config->{'PATH_FILES_IMG'}           // $PATH_ROOT.'data/files_img/';
our $PATH_FILES_SOURCE         = $config->{'PATH_FILES_SOURCE'}        // $PATH_ROOT.'data/files_sources/';
our $PATH_POSTERS              = $config->{'PATH_POSTERS'}             // $PATH_ROOT.'data/posters/';
our $PATH_SHOTS                = $config->{'PATH_SHOTS'}               // $PATH_ROOT.'data/shots/';
our $PATH_PHOTOS               = $config->{'PATH_PHOTOS'}              // $PATH_ROOT.'data/photos/';

our $URL_FILES                 = $config->{'URL_FILES'}                // $SITE_DATA_URL.'files_web/';
our $URL_FILES_IMG             = $config->{'URL_FILES_IMG'}            // $SITE_DATA_URL.'files_img/';
our $URL_POSTERS               = $config->{'URL_POSTERS'}              // $SITE_DATA_URL.'posters/';
our $URL_SHOTS                 = $config->{'URL_SHOTS'}                // $SITE_DATA_URL.'shots/';
our $URL_PHOTOS                = $config->{'URL_PHOTOS'}               // $SITE_DATA_URL.'photos/';
our $URL_USERS_DATA            = $config->{'URL_USERS_DATA'}           // $SITE_DATA_URL.'tmp/';

our $URL_POSTERS_DEF           = $config->{'URL_POSTERS_DEF'}          // $URL_POSTERS.'0.jpg';
our $URL_POSTERS_DEF_MINI      = $config->{'URL_POSTERS_DEF_MINI'}     // $URL_POSTERS.'0_mini.jpg';
our $URL_PHOTOS_DEF            = $config->{'URL_PHOTOS_DEF'}           // $URL_PHOTOS.'0.jpg';
our $URL_PHOTOS_DEF_MINI       = $config->{'URL_PHOTOS_DEF_MINI'}      // $URL_PHOTOS.'0_mini.jpg';

our $IMG_SUF_ORIG              = $config->{'IMG_SUF_ORIG'}             // '';
our $IMG_SUF_STD               = $config->{'IMG_SUF_STD'}              // '_std_';
our $IMG_SUF_MINI              = $config->{'IMG_SUF_MINI'}             // '_mini_';

our $IMG_POSTER_X              = $config->{'IMG_POSTER_X'}             // 200;
our $IMG_POSTER_Y              = $config->{'IMG_POSTER_Y'}             // 283;
our $IMG_POSTER_MINI_X         = $config->{'IMG_POSTER_MINI_X'}        // 120;
our $IMG_POSTER_MINI_Y         = $config->{'IMG_POSTER_MINI_Y'}        // 170;
our $IMG_PHOTO_X               = $config->{'IMG_PHOTO_X'}              // 200;
our $IMG_PHOTO_Y               = $config->{'IMG_PHOTO_Y'}              // 283;
our $IMG_PHOTO_MINI_X          = $config->{'IMG_PHOTO_MINI_X'}         // 120;
our $IMG_PHOTO_MINI_Y          = $config->{'IMG_PHOTO_MINI_Y'}         // 170;
our $IMG_SHOT_X                = $config->{'IMG_SHOT_X'}               // 350;
our $IMG_SHOT_Y                = $config->{'IMG_SHOT_Y'}               // 350;
our $IMG_SHOT_MINI_X           = $config->{'IMG_SHOT_MINI_X'}          // 100;
our $IMG_SHOT_MINI_Y           = $config->{'IMG_SHOT_MINI_Y'}          // 80;
our $MAX_AUTO_SHOTS            = $config->{'MAX_AUTO_SHOTS'}           // 8;

our $PATH_LOG_DB               = $config->{'PATH_LOG_DB'}              // $PATH_LOGS.'/db.log';
our $PATH_LOG_FFMPEG           = $config->{'PATH_LOG_FFMPEG'}          // $PATH_LOGS.'/ffmpeg.log';
our $PATH_LOG_VK               = $config->{'PATH_LOG_VK'}              // $PATH_LOGS.'/vk.log';
our $PATH_LOG_PFACE            = $config->{'PATH_LOG_PFACE'}           // $PATH_LOGS.'/pface.log';

our $AUTH_COOKIE_PFACE_1       = $config->{'AUTH_COOKIE_PFACE_1'}      // 'pface_s1';
our $AUTH_COOKIE_PFACE_2       = $config->{'AUTH_COOKIE_PFACE_2'}      // 'pface_s2';
our $AUTH_COOKIE_VK_ID         = $config->{'AUTH_COOKIE_VK_ID'}        // 'vkid';
our $AUTH_COOKIE_VK_SESS       = $config->{'AUTH_COOKIE_VK_SESS'}      // 'vksess';
our $AUTH_COOKIE_FROM          = $config->{'AUTH_COOKIE_FROM'}         // 'from';

our $PLAYER_PLAYLIST_WIDTH     = $config->{'PLAYER_PLAYLIST_WIDTH'}    // 310;
our $PLAYER_TRAILER_WIDTH_MAX  = $config->{'PLAYER_TRAILER_WIDTH_MAX'} // 300;
our $VIDEO_MAX_HEIGHT          = $config->{'VIDEO_MAX_HEIGHT'}         // 800;
our $VIDEO_MAX_WIDTH           = $config->{'VIDEO_MAX_WIDTH'}          // 1280;
our $VIDEO_MAX_BITRATE         = $config->{'VIDEO_MAX_BITRATE'}        // 6000;

our $COUNT_OBJECT_ANONCE       = $config->{'COUNT_OBJECT_ANONCE'}      // 20;

our $KINOPOISK_URI_POSTER      = $config->{'KINOPOISK_URI_POSTER'}     // 'https://st.kp.yandex.net';

our $HTML_TEMPLATE_SELECT      = '<option value="%ID%">%TITLE%</option>';

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
              $AUTH_PFACE_ID
              $AUTH_PFACE_KEY
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
              $PATH_LOG_PFACE
              $AUTH_COOKIE_PFACE_1
              $AUTH_COOKIE_PFACE_2
              $AUTH_COOKIE_VK_ID
              $AUTH_COOKIE_VK_SESS
              $AUTH_COOKIE_FROM
              $PLAYER_PLAYLIST_WIDTH
              $PLAYER_TRAILER_WIDTH_MAX
              $VIDEO_MAX_HEIGHT
              $VIDEO_MAX_WIDTH
              $VIDEO_MAX_BITRATE
              $COUNT_OBJECT_ANONCE
              $KINOPOISK_URI_POSTER
              $HTML_TEMPLATE_SELECT
              %LIST_GENRES
              %LIST_COUNTRIES
              %LIST_TRANSLATE
              %ALLOW_AGE
);

1;
