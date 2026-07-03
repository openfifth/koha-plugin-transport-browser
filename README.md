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

### Accessing the Transport Browser

1. Log in to the Koha Staff Interface
2. Navigate to **Tools > Plugins**
3. Find "Transport Browser" in the plugins list
4. Click "Run" or access directly via the plugin's tool link

### Configuring Transport Servers

Before using the Transport Browser, ensure transport servers are configured:

1. Go to **Administration > SFTP Servers**
2. Click "Add a new SFTP server" or "New FTP server"
3. Fill in the connection details:
   - **Server name**: A descriptive name for the server
   - **Host**: The server hostname or IP address
   - **Port**: Connection port (default 22 for SFTP, 21 for FTP)
   - **Username**: Login username
   - **Password**: Login password (stored securely)
   - **Download directory**: Optional default download path
4. Test the connection to ensure it works
5. Save the configuration

### Basic Directory Browsing

1. **Select a Transport Server**
   - From the Transport Browser main page, you'll see cards for each configured server
   - Each card shows server type (SFTP/FTP), host, port, and username
   - Click "Browse" on the desired server card

2. **Navigate Directories**
   - The current path is displayed at the top
   - Click on folder names to enter subdirectories
   - Use "Parent Directory" button to go up one level
   - Use "Root" button to return to the server's root directory

3. **View File Information**
   - Files and folders are listed in a table with columns:
     - **Name**: File/folder name (folders are shown in bold)
     - **Size**: File size in bytes (folders show "—" )
     - **Modified**: Last modification date and time
     - **Permissions**: Unix-style permissions (e.g., `-rw-r--r--` or `drwxr-xr-x`)

### Common Workflows for Librarians

#### Checking Available Files for Import

- Use the Transport Browser to verify MARC files or other resources are available on vendor servers
- Note file sizes and modification dates to track updates
- Check permissions to ensure files are readable

#### Verifying Server Connectivity

- Attempt to browse a server to confirm it's accessible
- If connection fails, check server configuration or contact system administrator
- Use for routine monitoring of data supplier connections

#### Finding Specific Files

- Navigate through directory structures to locate specific files
- Use the table sorting (click column headers) to organize by name, size, or date
- Check modification times to identify recently updated files

#### Directory Structure Analysis

- Browse to understand how vendor organizes their file deliveries
- Identify recurring directories or naming patterns
- Plan automated import configurations based on observed structures

### Common Workflows for Administrators

#### Server Configuration Management

- Regularly review configured transport servers
- Update credentials as needed
- Add new vendor servers as library acquires new data sources

#### Troubleshooting Connection Issues

- Test connections through the Transport Browser interface
- Check server logs for connection attempts
- Verify firewall settings and network connectivity

#### File System Monitoring

- Monitor available disk space on remote servers (if accessible)
- Check for unusual file permissions or ownership
- Verify data integrity by checking file sizes against expectations

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
