/**
 * semantic-release configuration
 * Level: Project (standalone)
 *
 * Converted from .releaserc.yml to .releaserc.js for better compatibility
 * Research: .releaserc.js is more reliable than YAML format
 */

module.exports = {
  branches: [
    'main',
    {
      name: 'feature/cci-neutrality-indicator',
      prerelease: 'beta'
    }
  ],
  plugins: [
    '@semantic-release/commit-analyzer',
    '@semantic-release/release-notes-generator',
    [
      '@semantic-release/changelog',
      {
        changelogFile: 'CHANGELOG.md'
      }
    ],
    '@semantic-release/exec',
    [
      '@semantic-release/git',
      {
        assets: ['CHANGELOG.md', 'package.json']
      }
    ],
    '@semantic-release/github'
  ]
};
