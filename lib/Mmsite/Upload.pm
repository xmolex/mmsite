package Mmsite::Upload;
######################################################################################
# модуль сохранения файла в пользовательской директории
######################################################################################
use Dancer2 appname => 'Mmsite';
use Modern::Perl;
use utf8;
use File::Copy;
use Mmsite::Lib::Vars;
use Mmsite::Lib::Subs;
use Mmsite::Lib::Members;

prefix '/upload';

# загружаем файл на сервер в пользовательскую директорию
post '' => sub {
    # отдаем результат в json
    response_header 'Content-Type' => 'application/json; charset=utf-8'; 

    my $member_obj = Mmsite::Lib::Members->new();
    return '{"error":"access denied"}' if $member_obj->role < 2;
    
    # пользовательская директория
    my $path_user = $PATH_USERS . '/' . $member_obj->id . '/';
    
    # проверяем, существует ли пользовательская директория
    unless (-d $path_user) {
        # создаем
        return '{"error":"do not create user dir"}' unless ( mkdir($path_user) );
    }
    
    # получаем данные по файлу из nginx
    my $original_filename   = body_parameters->get('origname');
    my $upload_file_name    = body_parameters->get('name');
    my $upload_content_type = body_parameters->get('content_type');
    my $upload_tmp_path     = body_parameters->get('path');

    return '{"error":"do not save file in temp dir"}' unless (-f $upload_tmp_path);
    
    # переводим имя файла в безопасное
    $original_filename = convert_filename_to_latin $original_filename;
    $original_filename = time() unless $original_filename;
    
    # перемещаем в пользовательскую директорию
    move( $upload_tmp_path, $path_user . $original_filename );
    
    return '{"error":"do not save file in user dir"}' unless ( -f $path_user . $original_filename );
    
    # получаем размер файла
    my @size = stat( $path_user . $original_filename );
    my $size = $size[7];
    
    # если все получилось, то отдаем истину
    my %return = ( 'file' => { 'name' => $original_filename, 'type' => $upload_content_type, 'size' => $size } );
    return to_json \%return;

};

1;
