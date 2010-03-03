use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'POE::Component::Client::Redis',
    license             => 'perl',
    dist_author         => 'Dexter Tad-y <dtady@cpan.org>',
    dist_version_from   => 'lib/POE/Component/Client/Redis.pm',
    build_requires => {
        'Test::More' => 0,
        'POE'        => 1,
    },
    add_to_cleanup      => [ 'POE-Component-Client-Redis-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
