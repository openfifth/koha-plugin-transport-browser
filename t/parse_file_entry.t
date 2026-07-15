#!/usr/bin/perl

use Modern::Perl;
use Test::More tests => 4;
use JSON::MaybeXS qw(decode_json);
use Path::Tiny qw(path);

my $plugin_dir = $ENV{KOHA_PLUGIN_DIR} || '.';
unshift @INC, $plugin_dir;

my $package_json  = decode_json( path($plugin_dir)->child('package.json')->slurp );
my $plugin_module = $package_json->{plugin}->{module};

use_ok($plugin_module);
my $plugin = $plugin_module->new();

subtest '_parse_file_entry' => sub {
    plan tests => 6;

    my $file_entry = $plugin->_parse_file_entry(
        {
            filename => 'QUOTES_413514.CEQ',
            size     => 1234,
            mtime    => 1700000100,
            perms    => '0644',
            type     => 'file',
        }
    );
    is( $file_entry->{name},   'QUOTES_413514.CEQ', 'name copied from filename' );
    is( $file_entry->{size},   1234,                'size copied through' );
    is( $file_entry->{is_dir}, 0,                   'type=file means is_dir false' );
    is( $file_entry->{perms},  '-rw-r--r--',         'perms formatted from octal + type' );

    my $dir_entry = $plugin->_parse_file_entry(
        {
            filename => 'incoming',
            size     => undef,
            mtime    => undef,
            perms    => '0755',
            type     => 'directory',
        }
    );
    is( $dir_entry->{is_dir}, 1,             'type=directory means is_dir true' );
    is( $dir_entry->{perms},  'drwxr-xr-x',  'perms formatted from octal + type, directory bit shown' );
};

subtest '_format_perms' => sub {
    plan tests => 2;

    is( $plugin->_format_perms( undef, 'file' ), '', 'undef perms formats to empty string' );
    is( $plugin->_format_perms( '0111', 'directory' ), 'd--x--x--x', 'execute-only perms format correctly' );
};

subtest '_format_file_list sorts directories first' => sub {
    plan tests => 1;

    my $raw = [
        { filename => 'b_file.txt', type => 'file',      size => 1, mtime => 1, perms => '0644' },
        { filename => 'a_dir',      type => 'directory', size => undef, mtime => undef, perms => '0755' },
    ];

    my $formatted = $plugin->_format_file_list($raw);
    is_deeply(
        [ map { $_->{name} } @{$formatted} ],
        [ 'a_dir', 'b_file.txt' ],
        'directories sort before files regardless of name order'
    );
};

1;
