const { readFileSync, existsSync } = require('node:fs');
const { resolve } = require('node:path');
const assert = require('node:assert/strict');
const root = resolve(__dirname, '..');
const read = (path) => readFileSync(resolve(root, path), 'utf8');
const applicationId = 'com.tahasaleem.familyguard';

// Compare the independent native, FlutterFire and backend configurations before
// a build. A valid-looking package with the wrong Firebase app must fail CI.
function verify() {
  const services = JSON.parse(read('android/app/google-services.json'));
  const project = services.project_info;
  const clients = services.client.filter((client) =>
    client.client_info.android_client_info.package_name === applicationId);
  assert.equal(clients.length, 1, 'Exactly one Firebase client must match the approved package');
  const client = clients[0], appId = client.client_info.mobilesdk_app_id;
  assert.equal(project.project_id, 'familyguard-v2-app', 'Unexpected Firebase project');
  assert.match(appId, new RegExp(`^1:${project.project_number}:android:[a-f0-9]+$`));
  const gradle = read('android/app/build.gradle.kts');
  assert.ok(gradle.includes(`val approvedApplicationId = "${applicationId}"`), 'Gradle identity differs');
  assert.ok(gradle.includes(`namespace = "${applicationId}"`), 'Android namespace differs');
  const activity = `android/app/src/main/kotlin/${applicationId.replaceAll('.', '/')}/MainActivity.kt`;
  assert.ok(read(activity).startsWith(`package ${applicationId}`), 'Launcher package differs');
  assert.equal(existsSync(resolve(root, 'android/app/src/main/kotlin/com/example/family_guard/MainActivity.kt')), false,
    'Remove the obsolete launcher source');
  const options = read('lib/firebase_options.dart');
  for (const [name, value] of Object.entries({
    appId, projectId: project.project_id, messagingSenderId: project.project_number,
    storageBucket: project.storage_bucket, apiKey: client.api_key[0].current_key,
  })) assert.ok(options.includes(`${name}: '${value}'`), `Dart Firebase ${name} differs`);
  const flutterFire = JSON.parse(read('firebase.json')).flutter.platforms;
  assert.equal(flutterFire.android.default.appId, appId, 'Native FlutterFire app differs');
  assert.equal(flutterFire.dart['lib/firebase_options.dart'].configurations.android, appId,
    'Dart FlutterFire app differs');
  const worker = JSON.parse(read('workers/wrangler.jsonc').replace(/,\s*([}\]])/g, '$1'));
  assert.equal(worker.vars.FIREBASE_PROJECT_ID, project.project_id, 'Worker project differs');
  assert.equal(worker.vars.FIREBASE_PROJECT_NUMBER, project.project_number, 'Worker project number differs');
  assert.ok(worker.vars.FIREBASE_APP_IDS.split(',').includes(appId), 'Worker must accept the registered app');
  console.log(`Android identity verified: ${applicationId}; Firebase/native/Dart/Worker configuration agrees.`);
}
if (require.main === module) {
  try { verify(); } catch (error) {
    console.error(`Android identity check failed: ${error.message}`);
    process.exitCode = 1;
  }
}
module.exports = { verify };
