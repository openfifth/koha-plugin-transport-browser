# AGENTS.md - Koha Plugin Transport Browser

This file contains instructions and conventions for agentic coding assistants working on the koha-plugin-transport-browser project.

## Project Overview

This is a Koha plugin that provides an FTP/SFTP directory browser using Koha's File::Transport infrastructure. The plugin consists of:
- Perl module (`Koha/Plugin/Com/OpenFifth/TransportBrowser.pm`)
- Template Toolkit template (`tool.tt`)
- JavaScript/Node.js build tooling
- Perl test suite

## Build/Lint/Test Commands

### Testing

**Run all tests:**
```bash
prove t/
```

**Run a single test file:**
```bash
prove t/00-load.t
```

**Run tests with verbose output:**
```bash
prove -v t/
```

**Run tests in CI environment (Docker):**
The GitHub Actions workflow runs tests using koha-testing-docker:
```bash
prove /var/lib/koha/kohadev/plugins/t
```

### Building

**Create release package (.kpz file):**
```bash
npm run release
```

**Build commands:**
```bash
npm run release:patch    # Increment patch version and create release
npm run release:minor    # Increment minor version and create release
npm run release:major    # Increment major version and create release
```

### Version Management

**Increment versions:**
```bash
npm run version:patch    # 1.0.0 → 1.0.1
npm run version:minor    # 1.0.0 → 1.1.0
npm run version:major    # 1.0.0 → 2.0.0
```

## Code Style Guidelines

### Perl Code Style

**Imports and Pragmas:**
- Use `Modern::Perl;` at the top of all Perl files
- Import modules after pragmas
- Group related imports together

**Example:**
```perl
use Modern::Perl;
use base qw(Koha::Plugins::Base);

use CGI;
use Try::Tiny qw(catch try);
use Koha::File::Transports;
use Koha::Logger;
```

**Naming Conventions:**
- Package names: `Koha::Plugin::Com::OpenFifth::TransportBrowser`
- Methods: `snake_case` (e.g., `tool`, `_show_transport_list`, `_browse_transport`)
- Private methods: prefixed with underscore (e.g., `_format_file_list`)
- Variables: `snake_case` (e.g., `$transport_id`, `$current_path`)
- Constants: `UPPER_CASE` (e.g., `$VERSION`)

**Error Handling:**
- Use `Try::Tiny` for exception handling
- Log errors using `Koha::Logger`
- Return appropriate error responses to users

**Example:**
```perl
try {
    $transport->connect();
    $self->{logger}->info("Connected successfully");
}
catch {
    $connection_error = $_;
    $self->{logger}->error("Connection failed: $_");
};
```

**Documentation:**
- Use POD (Plain Old Documentation) format
- Document all public methods with `=head2` sections
- Include method descriptions, parameters, and return values

**Example:**
```perl
=head2 tool

Main tool entry point. Handles transport selection and directory browsing.

=cut
```

**Control Structures:**
- Use consistent bracing style (Koha standard)
- Prefer `unless` for negative conditions
- Use early returns to reduce nesting

**Example:**
```perl
sub _browse_transport {
    my ($self, $transport_id, $path) = @_;

    my $transport = Koha::File::Transports->find($transport_id);
    unless ($transport) {
        # Handle error and return early
        return;
    }

    # Continue with normal flow...
}
```

### JavaScript/Node.js Code Style

**ES6+ Features:**
- Use `const` and `let` instead of `var`
- Use arrow functions where appropriate
- Use template literals for string interpolation

**Example:**
```javascript
const fs = require('fs');
const path = require('path');

console.log(`Current version: ${packageJson.version}`);
```

**Error Handling:**
- Use try/catch blocks for synchronous operations
- Validate inputs and provide meaningful error messages
- Exit with appropriate error codes

**Example:**
```javascript
const bumpType = process.argv[2];
if (!['major', 'minor', 'patch'].includes(bumpType)) {
    console.error('Please specify version bump type: major, minor, or patch');
    process.exit(1);
}
```

**File Operations:**
- Use synchronous methods for simple scripts
- Validate file existence before operations
- Use descriptive variable names

**Example:**
```javascript
// Read package.json
const packageJson = JSON.parse(fs.readFileSync('package.json', 'utf8'));
console.log(`Current version in package.json: ${packageJson.version}`);
```

### Template Toolkit (TT) Code Style

**Structure:**
- Use semantic HTML5 elements
- Follow Bootstrap CSS framework conventions
- Include accessibility attributes where appropriate

**CSS Integration:**
- Use inline styles sparingly, prefer classes
- Follow BEM-like naming for custom CSS classes
- Use CSS custom properties (variables) when appropriate

**Example:**
```html
<style>
    .transport-card {
        border: 1px solid #ddd;
        border-radius: 8px;
        padding: 1em;
        margin-bottom: 1em;
        transition: box-shadow 0.2s;
    }
    .transport-card:hover {
        box-shadow: 0 2px 8px rgba(0,0,0,0.1);
    }
</style>
```

**JavaScript Integration:**
- Use jQuery for DOM manipulation (Koha standard)
- Initialize components in `$(document).ready()`
- Follow Koha's JavaScript patterns

**Example:**
```javascript
$(document).ready(function() {
    if ($('#file-listing').length) {
        $('#file-listing').DataTable({
            "paging": true,
            "pageLength": 25,
            "ordering": true,
            "order": [[0, "asc"]]
        });
    }
});
```

### General Guidelines

**File Organization:**
- Keep related functionality grouped together
- Use descriptive file and directory names
- Follow Koha's plugin directory structure

**Security:**
- Never log sensitive information (passwords, keys, tokens)
- Validate all user inputs
- Use appropriate escaping for HTML output (`| html` filter in TT)

**Performance:**
- Minimize database queries
- Use appropriate data structures
- Consider memory usage for large file listings

**Internationalization:**
- Use Koha's i18n system for user-facing strings
- Mark translatable strings with `[% t("String") | html %]`

**Version Control:**
- Follow conventional commit messages
- Keep commits focused on single changes
- Update version numbers appropriately

**Testing:**
- Write tests for new functionality
- Test error conditions
- Ensure tests pass before committing

## Dependencies and Libraries

**Perl Dependencies:**
- `Modern::Perl` - Modern Perl features
- `CGI` - Web interface
- `Try::Tiny` - Exception handling
- `Koha::File::Transports` - Transport infrastructure
- `Koha::Logger` - Logging
- `JSON::MaybeXS` - JSON parsing
- `Path::Tiny` - File operations

**Node.js Dependencies:**
- Standard Node.js modules (fs, path)
- JSON parsing for configuration

**Testing Dependencies:**
- `Test::More` - Test framework
- `Test::Exception` - Exception testing

## Common Patterns and Anti-patterns

**Good Patterns:**
- Early returns to reduce nesting
- Consistent error handling with try/catch
- Proper resource cleanup
- Meaningful variable and method names

**Anti-patterns to Avoid:**
- Deep nesting of conditionals
- Magic numbers/strings
- Inconsistent error handling
- Missing documentation
- Hardcoded values that should be configurable

## Development Workflow

1. **Setup:** Clone repository and run `npm install`
2. **Development:** Make changes following code style guidelines
3. **Testing:** Run `prove t/` to ensure tests pass
4. **Building:** Use `npm run release` to create deployable package
5. **Versioning:** Use appropriate version increment commands
6. **Documentation:** Update README.md and inline documentation as needed

## CI/CD Integration

The project uses GitHub Actions for:
- Automated testing on multiple Koha versions
- Release artifact creation (.kpz files)
- Dependency installation and testing

Ensure all changes maintain compatibility with the CI pipeline.</content>
<parameter name="filePath">/home/martin/Projects/koha-plugins/koha-plugin-transport-browser/AGENTS.md