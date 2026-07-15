# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- `_parse_file_entry`/`_format_perms` no longer branch per transport type.
  Requires the Koha core fix for bug 43078 (unified `list_files()` shape
  across FTP/Local/SFTP, including directories and a `type` field) - bumping
  `minimum_version` once that fix's target release is known.
- Directory browsing now also works against FTP servers (previously FTP
  listings never included subdirectories).

## [1.0.4] - 2026-07-03

### Fixed

- Restore directory browsing on Koha 25.11. The plugin previously passed a bare
  path string to `list_files`, which on some 25.11 variants is dereferenced as
  an options hashref, producing a fatal `Can't use string (...) as a HASH ref
  while "strict refs" in use` error on every connection. Listing now uses the
  portable `change_directory($path)` + argument-less `list_files()` sequence,
  which behaves consistently across all Koha 25.11 file-transport variants.
- Check the return value of `connect()`, which returns undef on failure instead
  of throwing, so connection failures are no longer silently masked.
- Surface the underlying transport error (from `object_messages`) in both the
  connection-error and listing-error views instead of a generic message.

### Changed

- Raised `minimum_version` to `25.11.00.000`. The plugin depends on
  `Koha::File::Transports`, which does not exist before Koha 25.11; the previous
  `24.11.00.000` floor could never load.

## [1.0.0] - 2026-01-19

### Added

- Initial release
- Transport selection view showing all configured FTP/SFTP servers
- Directory browser with navigation (parent directory, root)
- File listing with name, size, modification time, and permissions (SFTP)
- DataTables integration for sortable, searchable file listings
- Support for both FTP and SFTP transports via Koha::File::Transport infrastructure
