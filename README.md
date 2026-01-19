# Koha Plugin: Transport Browser

A Koha plugin tool that provides a simple FTP/SFTP directory browser using the Koha::File::Transport infrastructure.

## Features

- Browse configured FTP and SFTP transport servers
- Navigate remote directory structures
- View file listings with details (name, size, modification time, permissions)
- Works with Koha's built-in transport server configuration

## Requirements

- Koha 24.11 or later (requires Koha::File::Transport infrastructure)
- Configured transport servers (Administration > SFTP Servers)

## Installation

1. Download the latest `.kpz` file from the releases
2. Go to Koha Staff Interface > Administration > Plugins
3. Click "Upload plugin"
4. Select the downloaded `.kpz` file
5. Enable the plugin

## Usage

1. Go to Tools > Plugins > Transport Browser (or run from the plugins page)
2. Select a configured transport server from the list
3. Browse the remote directory structure
4. Click on folders to navigate, use "Parent Directory" to go up

## Building from Source

```bash
# Install dependencies (if not already installed)
npm install

# Create a release package
npm run release
```

This will create a `koha-plugin-transport-browser-vX.Y.Z.kpz` file.

## Version Management

```bash
# Increment patch version (1.0.0 -> 1.0.1)
npm run version:patch

# Increment minor version (1.0.0 -> 1.1.0)
npm run version:minor

# Increment major version (1.0.0 -> 2.0.0)
npm run version:major
```

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Author

Martin Renvoize
