const { existsSync, mkdirSync, writeFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { randomBytes } = require('node:crypto');
const { spawnSync } = require('node:child_process');

// Run once locally. Refuse to overwrite either the key or its credentials.
// Passwords travel through child-process environment only and are never logged.
function main() {
  const root = resolve(__dirname, '..');
  const directory = resolve(root, 'android/upload-keystore');
  const store = resolve(directory, 'familyguard-upload.p12');
  const properties = resolve(root, 'android/key.properties');
  if (existsSync(store) || existsSync(properties)) throw new Error('Signing files already exist; reuse them.');
  const keytool = process.env.JAVA_HOME
    ? resolve(process.env.JAVA_HOME, 'bin', process.platform === 'win32' ? 'keytool.exe' : 'keytool') : 'keytool';
  const password = randomBytes(32).toString('hex');
  mkdirSync(directory, { recursive: true });
  const result = spawnSync(keytool, [
    '-genkeypair', '-noprompt', '-storetype', 'PKCS12', '-keystore', store,
    '-alias', 'familyguard-upload', '-keyalg', 'RSA', '-keysize', '2048', '-validity', '10000',
    '-dname', 'CN=FamilyGuard Upload', '-storepass:env', 'FG_UPLOAD_PASSWORD',
    '-keypass:env', 'FG_UPLOAD_PASSWORD',
  ], { env: { ...process.env, FG_UPLOAD_PASSWORD: password }, stdio: ['ignore', 'pipe', 'pipe'], timeout: 30000 });
  if (result.status !== 0) throw new Error('Upload key generation failed. Inspect local JDK setup; no credentials were printed.');
  writeFileSync(properties, [
    'storeFile=upload-keystore/familyguard-upload.p12',
    `storePassword=${password}`, 'keyAlias=familyguard-upload', `keyPassword=${password}`, '',
  ].join('\n'), { flag: 'wx', mode: 0o600 });
  console.log('Created ignored local upload keystore and key.properties. Back up both securely outside this computer before publishing.');
}
if (require.main === module) {
  try { main(); } catch (error) { console.error(error.message); process.exitCode = 1; }
}
