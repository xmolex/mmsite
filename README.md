Это сайт - видео сервис, написанный на perl5 с использованием Dancer2.
Работающий пример можно посмотреть на xmolex.ru.

Проект прошел тестирование на FreeBSD 11.1 x86, в качестве фронтенда использовался Nginx 1.12.2.

Для работы необходимы:
    Perl 5.24.3
    Nginx 1.12.2 (c включенным HTTP_UPLOAD)
    ImageMagick 6.9.9
    ffmpeg 3.4
    Postgresql 9.6.6
    memcached 1.5.2
    qt-faststart

Особенности:
    Авторизация через vk.com.
    Добавление информации о файле с возможностью ее загрузки с kinopoisk.ru. Поддерживается капча с kinopoisk.ru.
    Возможность програмной генерации кадров из видео файла.
    Автоматическое перекодирование видео под веб, если необходимо.
    Автоматическое извлечение субтитров из видеофайла и возможность их включения в плеере.
    Возможно смотреть видео как через плеер, так и просто скачав.
    Работает с шаблонизатором Text::Xslate.
    
Установка на freebsd:
    mkdir /home/http
    pw groupadd http
    pw useradd http -d /home/http -g http -s /bin/sh
    chown -R http:http /home/http
    cd /home/http
    
    cpan -i Dancer2
    cpan -i Dancer2::Template::Xslate # у меня не вставал, пока не поставил 
    cpan -i Digest::MurmurHash
    cpan -i Modern::Perl
    cpan -i LWP
    cpan -i CGI
    cpan -i DBI
    cpan -i DBD::Pg
    cpan -i JSON::XS
    cpan -i Data::Structure::Util
    cpan -i Image::Magick
    cpan -i Cache::Memcached
    
    git clone https://github.com/xmolex/mmsite.git
    perl Makefile.PL
    make
    make test
    make clean # устанавливать не обязательно
    echo 'mmsite_enable="YES"' > /etc/rc.conf
    cp install/rc.d/mmsite /usr/lo cal/etc/rc.d/
    psql < install/postgresql/install.sql
    # приведите конфиг nginx в соответствие с конфигом из install/nginx/nginx.conf
    # проверьте настройки в lib/Mmsite/Lib/Vars.pm
    service mmsite start
    
# После установки
    После того, как авторизуетесь на сайте, выполните запрос, чтобы установить себе администраторские привилегии
    psql -U database mmsite -c "UPDATE members SET role=3;"
    
    Запускайте время от времени scripts/conv_to_web.cgi, чтобы происходило пережимание видео под web.
    
    