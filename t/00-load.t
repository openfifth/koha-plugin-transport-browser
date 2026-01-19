#!/usr/bin/perl

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;
use Test::More tests => 3;
use Test::Exception;
use JSON::MaybeXS qw(decode_json);
use Path::Tiny qw(path);

# Get the plugin directory path
my $plugin_dir = $ENV{KOHA_PLUGIN_DIR} || '.';
my $package_json_path = path($plugin_dir)->child('package.json');

# Add plugin directory to @INC
unshift @INC, $plugin_dir;

# Read package.json
my $package_json = decode_json($package_json_path->slurp);
my $plugin_module = $package_json->{plugin}->{module};
my $expected_version = $package_json->{version};

# Test module loading
use_ok($plugin_module);

# Test instantiation
my $plugin;
lives_ok { $plugin = $plugin_module->new() } 'Plugin can be instantiated';

# Test version
is($plugin->{metadata}->{version}, $expected_version, 'Plugin version matches package.json');
