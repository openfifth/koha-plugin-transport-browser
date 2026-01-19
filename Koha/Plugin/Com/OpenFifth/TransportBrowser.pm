package Koha::Plugin::Com::OpenFifth::TransportBrowser;

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

use base qw(Koha::Plugins::Base);

use CGI;
use Try::Tiny qw(catch try);

use Koha::File::Transports;
use Koha::Logger;

our $VERSION = '1.0.2';

our $metadata = {
    name            => 'Transport Browser',
    author          => 'Martin Renvoize',
    date_authored   => '2026-01-19',
    date_updated    => '2026-01-19',
    minimum_version => '24.11.00.000',
    maximum_version => undef,
    version         => $VERSION,
    description     => 'A Koha plugin tool that provides a simple FTP/SFTP directory browser using the Koha::File::Transport infrastructure.',
};

=head1 NAME

Koha::Plugin::Com::OpenFifth::TransportBrowser - FTP/SFTP directory browser plugin

=head1 DESCRIPTION

This plugin provides a staff interface tool for browsing remote FTP/SFTP
servers configured in Koha. It allows users to:

- Select from configured transport servers
- Browse remote directory structures
- View file listings with size and modification times

=cut

sub new {
    my ( $class, $args ) = @_;

    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    my $self = $class->SUPER::new($args);
    $self->{cgi} = CGI->new();
    $self->{logger} = Koha::Logger->get;

    return $self;
}

=head2 tool

Main tool entry point. Handles transport selection and directory browsing.

=cut

sub tool {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $transport_id = $cgi->param('transport_id');
    my $path = $cgi->param('path');

    if ( $transport_id ) {
        $self->_browse_transport( $transport_id, $path );
    }
    else {
        $self->_show_transport_list();
    }
}

=head2 _show_transport_list

Display list of available transports for selection.

=cut

sub _show_transport_list {
    my ( $self ) = @_;

    my $template = $self->get_template( { file => 'tool.tt' } );

    my @transports = Koha::File::Transports->search()->as_list;

    $template->param(
        view       => 'list',
        transports => \@transports,
    );

    $self->output_html( $template->output() );
}

=head2 _browse_transport

Connect to a transport and browse its directory structure.

=cut

sub _browse_transport {
    my ( $self, $transport_id, $path ) = @_;

    my $template = $self->get_template( { file => 'tool.tt' } );
    my $transport = Koha::File::Transports->find( $transport_id );

    unless ( $transport ) {
        $template->param(
            view  => 'error',
            error => "Transport with ID $transport_id not found",
        );
        $self->output_html( $template->output() );
        return;
    }

    my $transport_name = $transport->name || "Transport $transport_id";
    my $transport_type = $transport->transport || 'unknown';

    # Attempt connection
    my $connected = 0;
    my $connection_error;

    try {
        $transport->connect();
        $connected = 1;
        $self->{logger}->info("Transport Browser: Connected to '$transport_name'");
    }
    catch {
        $connection_error = $_;
        $self->{logger}->error("Transport Browser: Failed to connect to '$transport_name': $_");
    };

    unless ( $connected ) {
        $template->param(
            view           => 'error',
            error          => "Failed to connect to transport '$transport_name': $connection_error",
            transport_id   => $transport_id,
            transport_name => $transport_name,
        );
        $self->output_html( $template->output() );
        return;
    }

    # Change to requested directory if specified
    my $current_path = '/';
    if ( defined $path && $path ne '' ) {
        try {
            $transport->change_directory( $path );
            $current_path = $path;
        }
        catch {
            $self->{logger}->warn("Transport Browser: Failed to change to directory '$path': $_");
            # Try to stay at root
            try {
                $transport->change_directory( undef );
            }
            catch {
                # Ignore - we'll show what we can
            };
        };
    }

    # Get file listing
    my $files = [];
    my $listing_error;

    try {
        my $raw_files = $transport->list_files();
        $files = $self->_format_file_list( $raw_files, $transport_type );
    }
    catch {
        $listing_error = $_;
        $self->{logger}->error("Transport Browser: Failed to list files: $_");
    };

    # Build parent path for navigation
    my $parent_path = $self->_get_parent_path( $current_path );

    $template->param(
        view           => 'browse',
        transport_id   => $transport_id,
        transport_name => $transport_name,
        transport_type => uc($transport_type),
        current_path   => $current_path,
        parent_path    => $parent_path,
        files          => $files,
        listing_error  => $listing_error,
        file_count     => scalar @{$files},
    );

    $self->output_html( $template->output() );
}

=head2 _format_file_list

Format the raw file list from transport into a consistent structure.

=cut

sub _format_file_list {
    my ( $self, $raw_files, $transport_type ) = @_;

    return [] unless $raw_files && ref($raw_files) eq 'ARRAY';

    my @formatted;

    foreach my $file ( @{$raw_files} ) {
        my $entry = $self->_parse_file_entry( $file, $transport_type );
        next unless $entry;
        push @formatted, $entry;
    }

    # Sort: directories first, then by name
    @formatted = sort {
        ( $b->{is_dir} || 0 ) <=> ( $a->{is_dir} || 0 )
            || lc( $a->{name} ) cmp lc( $b->{name} )
    } @formatted;

    return \@formatted;
}

=head2 _parse_file_entry

Parse a single file entry from the transport's list_files output.

=cut

sub _parse_file_entry {
    my ( $self, $file, $transport_type ) = @_;

    my $entry = {
        name     => '',
        size     => 0,
        mtime    => '',
        is_dir   => 0,
        perms    => '',
    };

    if ( $transport_type eq 'sftp' ) {
        # SFTP returns { filename => '...', a => Net::SFTP::Foreign::Attributes }
        if ( ref($file) eq 'HASH' ) {
            $entry->{name} = $file->{filename} || '';

            if ( $file->{a} && $file->{a}->can('size') ) {
                $entry->{size}  = $file->{a}->size || 0;
                $entry->{mtime} = $self->_format_time( $file->{a}->mtime );
                $entry->{is_dir} = ( $file->{a}->perm & 0040000 ) ? 1 : 0;
                $entry->{perms} = $self->_format_perms( $file->{a}->perm );
            }
        }
    }
    elsif ( $transport_type eq 'ftp' ) {
        # FTP returns simple array of filenames
        if ( ref($file) eq '' ) {
            $entry->{name} = $file;
            # FTP doesn't give us detailed info via simple ls
        }
        elsif ( ref($file) eq 'HASH' ) {
            $entry->{name} = $file->{filename} || $file->{name} || '';
            $entry->{size} = $file->{size} || 0;
            $entry->{is_dir} = $file->{is_dir} || 0;
        }
    }
    else {
        # Generic fallback
        if ( ref($file) eq 'HASH' ) {
            $entry->{name} = $file->{filename} || $file->{name} || '';
        }
        elsif ( ref($file) eq '' ) {
            $entry->{name} = $file;
        }
    }

    # Skip . and ..
    return undef if $entry->{name} eq '.' || $entry->{name} eq '..';

    return $entry;
}

=head2 _format_time

Format Unix timestamp to readable date string.

=cut

sub _format_time {
    my ( $self, $timestamp ) = @_;

    return '' unless $timestamp;

    my @t = localtime($timestamp);
    return sprintf(
        "%04d-%02d-%02d %02d:%02d",
        $t[5] + 1900, $t[4] + 1, $t[3], $t[2], $t[1]
    );
}

=head2 _format_perms

Format Unix permissions to rwx string.

=cut

sub _format_perms {
    my ( $self, $mode ) = @_;

    return '' unless defined $mode;

    my @chars = qw(--- --x -w- -wx r-- r-x rw- rwx);
    my $perms = '';

    # Directory/file indicator
    $perms .= ( $mode & 0040000 ) ? 'd' : '-';

    # Owner, group, other permissions
    $perms .= $chars[ ( $mode >> 6 ) & 7 ];
    $perms .= $chars[ ( $mode >> 3 ) & 7 ];
    $perms .= $chars[ $mode & 7 ];

    return $perms;
}

=head2 _format_size

Format file size with human-readable units.

=cut

sub _format_size {
    my ( $self, $size ) = @_;

    return '0 B' unless $size;

    my @units = qw(B KB MB GB TB);
    my $unit = 0;

    while ( $size >= 1024 && $unit < $#units ) {
        $size /= 1024;
        $unit++;
    }

    return sprintf( "%.1f %s", $size, $units[$unit] );
}

=head2 _get_parent_path

Calculate the parent directory path.

=cut

sub _get_parent_path {
    my ( $self, $path ) = @_;

    return undef if !$path || $path eq '/' || $path eq '';

    # Remove trailing slash
    $path =~ s|/$||;

    # Get parent
    my @parts = split( m|/|, $path );
    pop @parts;

    my $parent = join( '/', @parts ) || '/';

    return $parent;
}

=head2 install

Plugin installation hook.

=cut

sub install {
    my ( $self, $args ) = @_;
    return 1;
}

=head2 upgrade

Plugin upgrade hook.

=cut

sub upgrade {
    my ( $self, $args ) = @_;
    return 1;
}

=head2 uninstall

Plugin uninstallation hook.

=cut

sub uninstall {
    my ( $self, $args ) = @_;
    return 1;
}

1;
