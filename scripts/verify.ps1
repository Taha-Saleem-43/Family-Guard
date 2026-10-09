$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
  # All future dependency/emulator downloads stay inside this checkout.
  $env:PUB_CACHE = Join-Path $repoRoot '.pub-cache'
  $env:npm_config_cache = Join-Path $repoRoot '.npm-cache'
  $env:FIREBASE_EMULATORS_PATH = Join-Path $repoRoot '.cache/firebase/emulators'
  $env:CI = 'true'
  flutter pub get
  if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed' }
  flutter analyze
  if ($LASTEXITCODE -ne 0) { throw 'Flutter analysis failed' }
  flutter test --coverage
  if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed' }
  npm.cmd ci --ignore-scripts
  if ($LASTEXITCODE -ne 0) { throw 'Node dependency resolution failed' }
  npm.cmd ci --prefix functions --ignore-scripts
  if ($LASTEXITCODE -ne 0) { throw 'Functions dependency resolution failed' }
  npm.cmd run test:backend
  if ($LASTEXITCODE -ne 0) { throw 'Backend tests failed' }
  npm.cmd run test:rules
  if ($LASTEXITCODE -ne 0) { throw 'Security tests failed' }
  npm.cmd run test:membership
  if ($LASTEXITCODE -ne 0) { throw 'Membership integration tests failed' }
  npm.cmd run test:sos
  if ($LASTEXITCODE -ne 0) { throw 'SOS integration tests failed' }
  npm.cmd run test:invites
  if ($LASTEXITCODE -ne 0) { throw 'Invite rotation integration tests failed' }
  npm.cmd run test:accounts
  if ($LASTEXITCODE -ne 0) { throw 'Account deletion integration tests failed' }
  npm.cmd run test:push
  if ($LASTEXITCODE -ne 0) { throw 'Push delivery integration tests failed' }
} finally {
  Pop-Location
}
