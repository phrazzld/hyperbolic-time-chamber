# TestFlight Deployment System

This document describes the automated TestFlight deployment pipeline for the WorkoutTracker iOS app, enabling continuous delivery of beta builds to testers.

## Overview

The deployment system uses **Fastlane** + **GitHub Actions** to provide:
- Automated build generation and code signing
- TestFlight upload and distribution
- Build number management and versioning
- Secure certificate and credential management
- Automated changelog generation

## Architecture

### Deployment Pipeline

```
Code Push/Tag → GitHub Actions → Fastlane → Code Signing → Build → TestFlight Upload → Tester Notification
```

1. **Trigger**: Manual workflow dispatch or version tag push
2. **Environment Setup**: Xcode, certificates, provisioning profiles
3. **Build Process**: Fastlane builds signed IPA for distribution
4. **Upload**: Automatic upload to App Store Connect/TestFlight
5. **Distribution**: Optional tester notification and changelog delivery

### Key Components

- **fastlane/Fastfile**: Main deployment configuration and lanes
- **fastlane/Appfile**: App-specific settings (bundle ID, team ID)
- **.github/workflows/deploy-testflight.yml**: GitHub Actions workflow
- **Certificate Management**: Secure handling of code signing assets

## Prerequisites

### Apple Developer Account Setup

1. **Apple Developer Program**: Active paid membership required
2. **App Store Connect Access**: Administrative or developer role
3. **Bundle Identifier**: Registered app identifier (`com.yourcompany.WorkoutTracker`)
4. **Distribution Certificate**: Valid iOS distribution certificate
5. **Provisioning Profile**: App Store distribution provisioning profile

### App Store Connect Configuration

1. **App Creation**: Create app in App Store Connect with correct bundle ID
2. **TestFlight Setup**: Configure TestFlight settings and testing groups
3. **API Key**: Generate App Store Connect API key with appropriate permissions

**API Key Permissions Required:**
- App Manager or Developer role
- Access to TestFlight and app management features

## GitHub Secrets Configuration

The deployment system requires the following GitHub repository secrets:

### Required Secrets

| Secret Name | Description | Example/Format |
|-------------|-------------|----------------|
| `TEAM_ID` | Apple Developer Team ID | `ABCDEF1234` |
| `APPLE_ID` | Apple ID email address | `developer@company.com` |
| `APP_STORE_CONNECT_API_KEY_ID` | API Key ID | `ABC123DEF4` |
| `APP_STORE_CONNECT_API_ISSUER_ID` | API Key Issuer ID | `12345678-1234-1234-1234-123456789012` |
| `APP_STORE_CONNECT_API_KEY` | Base64 encoded API key file | `LS0tLS1CRUdJT...` |

### Certificate Management Secrets

**Option 1: Manual Certificate Management**
| Secret Name | Description |
|-------------|-------------|
| `DISTRIBUTION_CERTIFICATE_P12_BASE64` | Base64 encoded distribution certificate |
| `DISTRIBUTION_CERTIFICATE_PASSWORD` | Certificate password |
| `PROVISIONING_PROFILE_BASE64` | Base64 encoded provisioning profile |

**Option 2: Fastlane Match (Recommended)**
| Secret Name | Description |
|-------------|-------------|
| `MATCH_GIT_URL` | Private git repository URL for certificates |
| `MATCH_PASSWORD` | Encryption password for certificates |

### Optional Secrets

| Secret Name | Description | Default |
|-------------|-------------|---------|
| `ITC_TEAM_ID` | App Store Connect Team ID | Uses `TEAM_ID` |

## Usage

### Manual Deployment

Deploy to TestFlight manually via GitHub Actions:

1. Navigate to **Actions** tab in GitHub repository
2. Select **Deploy to TestFlight** workflow
3. Click **Run workflow**
4. Configure options:
   - **Environment**: `beta` or `internal`
   - **Notify Testers**: Whether to send notifications
   - **Changelog**: Custom release notes (optional)
5. Monitor deployment progress in workflow logs

### Automatic Deployment

Trigger deployment automatically by pushing version tags:

```bash
# Create and push a version tag
git tag v1.0.0
git push origin v1.0.0

# Create and push a beta tag
git tag beta-1.0.0-1
git push origin beta-1.0.0-1
```

**Tag Formats:**
- `v*.*.*`: Production release versions
- `beta-*`: Beta releases
- `alpha-*`: Alpha releases (marked as prerelease)

### Build Numbers

Build numbers are automatically managed:
- **CI Environment**: Uses GitHub run number (`GITHUB_RUN_NUMBER`)
- **Local Development**: Uses timestamp
- **Manual Override**: Can be configured via Fastlane parameters

### Changelog Generation

Changelogs are automatically generated from git commits:
- **Automatic**: Parses commits since last git tag
- **Manual Override**: Specify custom changelog in workflow dispatch
- **Format**: Markdown-formatted bullet points
- **Length Limit**: Truncated to 4000 characters for TestFlight

## TestFlight Configuration

### Testing Groups

The deployment system supports multiple testing groups:

- **Internal Testing**: Immediate access for internal team members
- **External Testing**: Beta testers requiring Apple review
- **Custom Groups**: Configured in App Store Connect

### Build Distribution

**Default Configuration:**
- Uploads to TestFlight without automatic submission
- Internal testers get immediate access
- External testers require manual notification
- Groups can be configured in Fastfile

### Notification Settings

**Tester Notifications:**
- Controlled via workflow input or Fastfile configuration
- Includes changelog and build information
- Respects TestFlight notification preferences

## Local Development

### Setup Fastlane

```bash
# Install Fastlane
gem install fastlane

# Initialize Fastlane (if needed)
cd fastlane
fastlane init

# Run local build
fastlane build

# Test deployment (requires certificates)
fastlane beta
```

### Certificate Management

**Using Fastlane Match (Recommended):**
```bash
# Setup match
fastlane match init

# Generate certificates
fastlane match appstore

# Sync certificates
fastlane match appstore --readonly
```

**Manual Certificate Export:**
```bash
# Export certificate to base64
base64 -i certificate.p12 -o certificate.txt

# Export provisioning profile
base64 -i profile.mobileprovision -o profile.txt
```

## Troubleshooting

### Common Issues

**Build Failures:**
- **Cause**: Code signing errors, missing certificates
- **Solution**: Verify certificate validity and provisioning profile
- **Check**: Fastlane logs for specific signing errors

**Upload Failures:**
- **Cause**: App Store Connect API issues, network problems
- **Solution**: Verify API key permissions and network connectivity
- **Check**: API key expiration and App Store Connect status

**Version Conflicts:**
- **Cause**: Build number already exists in TestFlight
- **Solution**: Increment build number or use auto-increment
- **Check**: App Store Connect for existing build numbers

### Debug Commands

```bash
# Test Fastlane configuration
fastlane lanes

# Validate certificates
security find-identity -v -p codesigning

# Check provisioning profiles
ls ~/Library/MobileDevice/Provisioning\ Profiles/

# Test API key
fastlane spaceship
```

### Log Analysis

**Key Log Locations:**
- GitHub Actions workflow logs
- Fastlane build logs (`fastlane/logs/`)
- Xcode build logs
- App Store Connect processing logs

**Common Error Patterns:**
- Certificate/provisioning profile mismatches
- Bundle identifier inconsistencies
- API authentication failures
- Network timeout issues

## Security Considerations

### Credential Protection

- **GitHub Secrets**: All sensitive data stored in encrypted secrets
- **Base64 Encoding**: Certificates encoded for secure transmission
- **Temporary Storage**: Credentials cleaned up after deployment
- **Limited Scope**: API keys have minimal required permissions

### Access Control

- **Repository Access**: Limit deployment workflow access to authorized users
- **Secret Management**: Regular rotation of certificates and API keys
- **Audit Trail**: GitHub Actions provides complete deployment audit trail

### Certificate Management

**Security Best Practices:**
- Use Fastlane Match for team certificate management
- Regular certificate renewal before expiration
- Secure storage of certificate encryption passwords
- Limited access to certificate repositories

## Monitoring and Maintenance

### Deployment Monitoring

**Key Metrics:**
- Deployment success/failure rate
- Build processing time
- TestFlight upload duration
- Tester adoption rate

**Monitoring Tools:**
- GitHub Actions workflow history
- App Store Connect analytics
- TestFlight crash reports and feedback

### Maintenance Tasks

**Regular Maintenance:**
- Certificate renewal (annual)
- API key rotation (as needed)
- Provisioning profile updates
- TestFlight group management

**Version Management:**
- Tag cleanup for old releases
- Build artifact cleanup (automated)
- Changelog quality review
- Release note standardization

## Advanced Configuration

### Custom Build Configurations

Modify `fastlane/Fastfile` for custom requirements:

```ruby
# Custom export options
export_options: {
  method: "app-store",
  teamID: TEAM_ID,
  uploadBitcode: false,
  uploadSymbols: true,
  compileBitcode: false,
  # Add custom settings here
}
```

### Multi-Target Support

For apps with multiple targets or schemes:

```ruby
# Build multiple targets
["Main", "Extension"].each do |scheme|
  build_app(scheme: scheme, ...)
end
```

### Environment-Specific Configurations

```ruby
# Environment-based configuration
case ENV["ENVIRONMENT"]
when "staging"
  # Staging-specific settings
when "production"
  # Production-specific settings
end
```

## Future Enhancements

### Planned Improvements

1. **Automated Screenshot Generation**: Generate App Store screenshots
2. **Release Notes Automation**: Generate from commit messages and PR titles
3. **Version Bumping**: Automated semantic versioning
4. **Multi-Environment Support**: Staging, production, and development builds
5. **Advanced Testing**: Integration with automated testing before deployment

### Integration Opportunities

- **Slack Notifications**: Deployment status updates
- **JIRA Integration**: Release tracking and issue resolution
- **Analytics Integration**: Build performance and adoption metrics
- **Quality Gates**: Advanced testing and quality checks before deployment

---

*TestFlight Deployment System Version: 1.0*
*Last Updated: December 2024*