use strict;
use warnings;
use ExtUtils::MakeMaker;

# Normalize version strings like 6.30_02 to 6.3002,
# so that we can do numerical comparisons on it.
my $eumm_version = $ExtUtils::MakeMaker::VERSION;
$eumm_version =~ s/_//;

WriteMakefile(
    NAME                => 'Mmsite',
    AUTHOR              => q{Konstantin Titov <xmolex@list.ru>},
    VERSION_FROM        => 'lib/Mmsite.pm',
    ABSTRACT            => '',
    ($eumm_version >= 6.3001
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More'                => 0,
        'YAML'                      => 0,
        'Dancer2'                   => 0.205002,
        'Dancer2::Template::Xslate' => 'v0.1.1',
        'Digest::MurmurHash'        => 0.11,
        'Modern::Perl'              => 1.20170117,
        'LWP'                       => 5.64,
        'CGI'                       => 4.38,
        'DBI'                       => 1.637,
        'DBD::Pg'                   => '3.7.0',
        'JSON::XS'                  => 3.04,
        'Data::Structure::Util'     => 0.16,
        'Image::Magick'             => 0.16,
        'Cache::Memcached'          => 1.30
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Mmsite-*' },
);
