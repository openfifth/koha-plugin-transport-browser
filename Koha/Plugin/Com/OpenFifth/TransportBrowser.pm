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

our $VERSION = '1.0.7';

our $metadata = {
    name            => 'Transport Browser',
    author          => 'Martin Renvoize',
    date_authored   => '2026-01-19',
    date_updated    => '2026-07-03',
    minimum_version => '25.11.00.000',
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
    #
    # Note: Koha::File::Transport::connect() returns a true value on success
    # and undef on failure (recording details via object_messages) rather than
    # throwing, so we must check the return value explicitly. The try/catch
    # still guards against the protocol layer die-ing unexpectedly.
    my $connected = 0;
    my $connection_error;
    my $base_path = '/';

    try {
        $connected = $transport->connect();

        if ( $connected ) {
            $self->{logger}->info("Transport Browser: Connected successfully");

            # Determine the base path (initial working directory)
            if ($transport->{connection} && $transport->{connection}->can('cwd')) {
                $base_path = $transport->{connection}->cwd // '/';
                $self->{logger}->info("Transport Browser: Base path (initial cwd): '$base_path'");
            }
        }
        else {
            $connection_error = $self->_get_transport_error( $transport )
                || 'Unknown connection error';
            $self->{logger}->error("Transport Browser: Failed to connect to '$transport_name': $connection_error");
        }
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

    # Determine the actual path to use for operations
    my $actual_path;
    my $display_path;

    if ( !defined $path || $path eq '' || $path eq '/' ) {
        $actual_path = $base_path;
        $display_path = '/';
    } else {
        # UI paths are absolute from user's perspective, convert to actual paths
        # Remove leading / from UI path and append to base_path
        my $relative_path = $path;
        $relative_path =~ s|^/||;
        $actual_path = $base_path eq '/' ? "/$relative_path" : "$base_path/$relative_path";
        $display_path = $path;
    }

    $self->{logger}->info("Transport Browser: UI path '$path' -> actual path '$actual_path', display path '$display_path'");

    # Navigate to the requested directory, then list it.
    #
    # We use change_directory() followed by an argument-less list_files() rather
    # than passing a path to list_files(). This is the lowest-common-denominator
    # API supported across all Koha 25.11 file-transport variants: some variants
    # accept a { path } option to list_files() while others ignore arguments and
    # simply list the current working directory. Changing directory explicitly
    # works everywhere and, on variants with automatic directory management, also
    # disables auto-switching to a configured download_directory so we list
    # exactly the directory the user navigated to. Both methods return a true
    # value / arrayref on success and undef on failure (details via
    # object_messages).
    my $files = [];
    my $listing_error;

    try {
        $self->{logger}->info("Transport Browser: Changing to directory '$actual_path'");
        unless ( $transport->change_directory($actual_path) ) {

            # Fall back to the base directory so the user still sees something
            my $error = $self->_get_transport_error($transport)
                || "Failed to change to directory '$display_path'";
            $self->{logger}->warn("Transport Browser: $error; falling back to base directory");
            $transport->change_directory($base_path);
            $display_path = '/';
        }

        $self->{logger}->info("Transport Browser: Listing files in '$display_path'");
        my $raw_files = $transport->list_files();

        if ( defined $raw_files ) {
            $files = $self->_format_file_list($raw_files);
            $self->{logger}->info("Transport Browser: Found " . scalar(@$files) . " files/directories");
            foreach my $file (@$files) {
                $self->{logger}->debug("Transport Browser: File: " . $file->{name} . " (dir: " . ($file->{is_dir} ? 'yes' : 'no') . ")");
            }
        }
        else {
            $listing_error = $self->_get_transport_error( $transport )
                || "Failed to list files in '$display_path'";
            $self->{logger}->error("Transport Browser: Failed to list files: $listing_error");
        }
    }
    catch {
        $listing_error = $_;
        $self->{logger}->error("Transport Browser: Failed to list files: $_");
    };

    # Build parent path for navigation (using display paths)
    my $parent_path = $self->_get_parent_path( $display_path );

    $template->param(
        view           => 'browse',
        transport_id   => $transport_id,
        transport_name => $transport_name,
        transport_type => uc($transport_type),
        current_path   => $display_path,
        parent_path    => $parent_path,
        files          => $files,
        listing_error  => $listing_error,
        file_count     => scalar @{$files},
    );

    $self->output_html( $template->output() );
}

=head2 _get_transport_error

Extract a human-readable error string from a transport's object_messages.

Koha::File::Transport records failures as messages of type 'error' whose
payload hashref carries C<error> (and, for SFTP, C<error_raw>) keys. Returns
the most recent error message, or undef if none is present.

=cut

sub _get_transport_error {
    my ( $self, $transport ) = @_;

    return unless $transport && $transport->can('object_messages');

    my $messages = $transport->object_messages;
    return unless $messages && ref($messages) eq 'ARRAY';

    for my $message ( reverse @{$messages} ) {
        next unless $message->type eq 'error';

        my $payload = $message->payload;
        if ( ref($payload) eq 'HASH' ) {
            return $payload->{error} || $payload->{error_raw} || $message->message;
        }
        return $message->message;
    }

    return;
}

=head2 _format_file_list

Format the raw file list from transport into a consistent structure.

=cut

sub _format_file_list {
    my ( $self, $raw_files ) = @_;

    return [] unless $raw_files && ref($raw_files) eq 'ARRAY';

    my @formatted;

    foreach my $file ( @{$raw_files} ) {
        my $entry = $self->_parse_file_entry($file);
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

Parse a single file entry from the transport's list_files output. All three
Koha::File::Transport backends (FTP, Local, SFTP) now return the same flat
shape (filename, size, mtime, perms, type), so no backend-specific parsing
is needed here.

=cut

sub _parse_file_entry {
    my ( $self, $file ) = @_;

    return undef unless ref($file) eq 'HASH' && defined $file->{filename} && length $file->{filename};

    return {
        name   => $file->{filename},
        size   => $file->{size} // 0,
        mtime  => $self->_format_time( $file->{mtime} ),
        is_dir => ( ( $file->{type} // '' ) eq 'directory' ) ? 1 : 0,
        perms  => $self->_format_perms( $file->{perms}, $file->{type} ),
    };
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

Format a Unix octal permissions string (e.g. "0644", as returned by
Koha::File::Transport's list_files) plus a type ('file'/'directory'/'other')
into an rwx display string (e.g. "-rw-r--r--" or "drwxr-xr-x").

=cut

sub _format_perms {
    my ( $self, $perms, $type ) = @_;

    return '' unless defined $perms;

    my $mode = oct($perms) & oct('07777');
    my @chars = qw(--- --x -w- -wx r-- r-x rw- rwx);

    my $out = ( ( $type // '' ) eq 'directory' ) ? 'd' : '-';
    $out .= $chars[ ( $mode >> 6 ) & 7 ];
    $out .= $chars[ ( $mode >> 3 ) & 7 ];
    $out .= $chars[ $mode & 7 ];

    return $out;
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
