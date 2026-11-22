import assert from 'node:assert/strict';

const project = process.env.GCLOUD_PROJECT ?? 'demo-kiji-sekkei';
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;

assert.match(project, /^demo-/);
for (const host of [authHost, firestoreHost]) {
  assert.match(host ?? '', /^127\.0\.0\.1:\d+$/);
}

async function signUp() {
  const response = await fetch(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ returnSecureToken: true }),
    },
  );
  assert.equal(response.status, 200, await response.clone().text());
  return response.json();
}

const owner = await signUp();
const other = await signUp();
const root = `projects/${project}/databases/(default)/documents`;
const base = `http://${firestoreHost}/v1/${root}`;
const record = '5d35cccd-ff13-4bbe-a4e0-3effabff9b75';

async function request(path, token, { method = 'GET', body } = {}) {
  return fetch(`${base}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

async function expectStatus(response, status) {
  assert.equal(response.status, status, await response.clone().text());
}

function write(path, user, revision, { deleted = false, extra = {} } = {}) {
  return request(':commit', user.idToken, {
    method: 'POST',
    body: {
      writes: [{
        update: {
          name: `${root}${path}`,
          fields: {
            revision: { integerValue: String(revision) },
            deleted: { booleanValue: deleted },
            payload: deleted
              ? { nullValue: null }
              : { mapValue: { fields: { title: { stringValue: '同期テスト' } } } },
            ...extra,
          },
        },
        updateTransforms: [{ fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' }],
      }],
    },
  });
}

for (const collection of ['drafts', 'templates']) {
  const path = `/users/${owner.localId}/${collection}/${record}`;
  await expectStatus(await write(path, owner, 2), 403);
  await expectStatus(await write(path, owner, 1), 200);
  await expectStatus(await request(path, owner.idToken), 200);
  await expectStatus(await request(path, other.idToken), 403);
  await expectStatus(await request(path), 403);
  await expectStatus(await write(path, other, 2), 403);
  await expectStatus(await write(path, owner, 1), 403);
  await expectStatus(await write(path, owner, 2, {
    extra: { unexpected: { stringValue: 'ignored' } },
  }), 403);
  await expectStatus(await write(path, owner, 2, { deleted: true }), 200);
  const result = await request(path, owner.idToken);
  await expectStatus(result, 200);
  const { fields } = await result.json();
  assert.equal(fields.deleted.booleanValue, true);
  assert.equal(fields.payload.nullValue, null);
  await expectStatus(await request(path, owner.idToken, { method: 'DELETE' }), 403);
}
await expectStatus(await write(`/users/${owner.localId}/unexpected/${record}`, owner, 1), 403);
console.log('Firestore rules: owner access, account isolation, revision checks, and deletion markers passed.');
