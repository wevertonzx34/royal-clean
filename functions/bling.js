import {createHash, randomBytes, timingSafeEqual} from 'node:crypto';
import {applicationDefault} from 'firebase-admin/app';
import {FieldValue, Timestamp} from 'firebase-admin/firestore';
import {HttpsError} from 'firebase-functions/v2/https';

export const BLING_CALLBACK_URL = 'https://southamerica-east1-royal-clean-fire.cloudfunctions.net/blingCallback';
const project = 'royal-clean-fire';
const cookieName = '__Host-royal_bling';
const cookieOptions = 'Path=/; HttpOnly; Secure; SameSite=Lax';
const digest = value => createHash('sha256').update(value).digest('hex');
const stateValid = value => typeof value === 'string' && /^[a-f0-9]{64}$/.test(value);
const fail = (message, code = 'failed-precondition') => { throw new HttpsError(code, message); };

// Lazy access allows deploying the real callback before Bling has issued credentials.
// Grant secretAccessor only on these two secrets to the runtime service account.
export async function readBlingCredentials() {
  try {
    const {access_token: token} = await applicationDefault().getAccessToken();
    const read = async name => {
      const response = await fetch(`https://secretmanager.googleapis.com/v1/projects/${project}/secrets/${name}/versions/latest:access`, {
        headers: {Authorization: `Bearer ${token}`}, signal: AbortSignal.timeout(8000), redirect: 'error',
      });
      if (!response.ok) throw new Error('Secret unavailable');
      const data = await response.json();
      const value = Buffer.from(data.payload.data, 'base64').toString('utf8').trim();
      if (!value || value.length > 8192 || /[\r\n]/.test(value)) throw new Error('Invalid secret');
      return value;
    };
    const [clientId, clientSecret] = await Promise.all([read('BLING_CLIENT_ID'), read('BLING_CLIENT_SECRET')]);
    return {clientId, clientSecret};
  } catch (_) {
    fail('Configure BLING_CLIENT_ID e BLING_CLIENT_SECRET no Secret Manager e libere a leitura para o backend.');
  }
}

export function validateBlingTokens(data) {
  if (!data || typeof data.access_token !== 'string' || data.access_token.length < 10 ||
      data.access_token.length > 16384 || typeof data.refresh_token !== 'string' ||
      data.refresh_token.length < 10 || data.refresh_token.length > 16384 ||
      !Number.isFinite(data.expires_in) || data.expires_in <= 0 || data.expires_in > 604800 ||
      String(data.token_type).toLowerCase() !== 'bearer') {
    fail('O Bling não retornou uma autorização válida. Inicie uma nova conexão.');
  }
  return {accessToken: data.access_token, refreshToken: data.refresh_token,
    expiresIn: data.expires_in, scope: typeof data.scope === 'string' ? data.scope.slice(0, 2000) : ''};
}

export async function exchangeBlingCode(code, credentials) {
  // Documented API v3 OAuth endpoint. Never send secrets or codes to the mobile client.
  const response = await fetch('https://api.bling.com.br/Api/v3/oauth/token', {
    method: 'POST', redirect: 'error', signal: AbortSignal.timeout(15000),
    headers: {'Content-Type': 'application/x-www-form-urlencoded', Accept: 'application/json',
      'enable-jwt': '1', Authorization: `Basic ${Buffer.from(`${credentials.clientId}:${credentials.clientSecret}`).toString('base64')}`},
    body: new URLSearchParams({grant_type: 'authorization_code', code, redirect_uri: BLING_CALLBACK_URL}),
  });
  if (!response.ok) fail('Não foi possível concluir a autorização no Bling. Inicie uma nova conexão.');
  return validateBlingTokens(await response.json());
}

function page(res, status, message) {
  // All messages are application-owned constants, never provider/query text.
  res.status(status).type('html').send(`<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Royal Clean · Bling</title><body><main><h1>Royal Clean</h1><h2>Integração com o Bling</h2><p>${message}</p><p>Você pode fechar esta página e retornar ao aplicativo.</p></main></body></html>`);
}

export function createBlingHandlers({db, auth, authenticated, requireAdmin, rateLimit,
  readCredentials = readBlingCredentials, exchangeCode = exchangeBlingCode}) {
  const connection = db.doc('integrations_private/bling');
  const attempt = db.doc('integrations_private/bling_attempt');
  async function adminRequest(request) {
    const user = await authenticated(request);
    await requireAdmin(user);
    return user;
  }
  async function sessionAdmin(uid) {
    const user = await auth.getUser(uid);
    if (user.disabled || !user.emailVerified || !user.email) fail('Acesso indisponível.', 'permission-denied');
    await requireAdmin(user);
  }
  async function release(hash) {
    await db.runTransaction(async tx => {
      const current = (await tx.get(attempt)).data();
      if (current?.hash === hash) tx.delete(attempt);
    });
  }

  return {
    async status(request) {
      await adminRequest(request);
      await rateLimit(request.auth.uid, 'bling_status', 20);
      const data = (await connection.get()).data();
      if (data) return {status: 'authorized', callbackUrl: BLING_CALLBACK_URL,
        connectedAt: data.connectedAt?.toDate().toISOString() ?? null,
        synchronizationEnabled: false, reauthorizationRequired: data.reauthorizationRequired === true};
      try {
        await readCredentials();
        return {status: 'ready', callbackUrl: BLING_CALLBACK_URL, synchronizationEnabled: false};
      } catch (_) {
        return {status: 'configuration_required', callbackUrl: BLING_CALLBACK_URL, synchronizationEnabled: false};
      }
    },
    async begin(request) {
      const user = await adminRequest(request);
      await rateLimit(user.uid, 'bling_connect', 3);
      await readCredentials();
      const state = randomBytes(32).toString('hex');
      const hash = digest(state);
      const expiresAt = Timestamp.fromMillis(Date.now() + 10 * 60000);
      await db.runTransaction(async tx => {
        const [connected, currentAttempt] = await Promise.all([tx.get(connection), tx.get(attempt)]);
        if (connected.exists && request.data?.reconnect !== true) fail('Uma conta Bling já foi autorizada. Use Renovar autorização.');
        if (currentAttempt.data()?.expiresAt?.toMillis() > Date.now()) {
          fail('Uma autorização está em andamento. Conclua no navegador ou aguarde até 10 minutos para tentar novamente.');
        }
        tx.set(db.doc(`bling_oauth_sessions/${hash}`), {uid: user.uid, expiresAt, status: 'pending',
          previousConnection: connected.data()?.connectedAt?.toMillis() ?? null,
          createdAt: FieldValue.serverTimestamp()});
        tx.set(attempt, {hash, expiresAt});
      });
      return {url: `${BLING_CALLBACK_URL}?start=${state}`};
    },
    async callback(req, res) {
      res.set('Cache-Control', 'no-store');
      res.set('Referrer-Policy', 'no-referrer');
      res.set('X-Content-Type-Options', 'nosniff');
      res.set('Content-Security-Policy', "default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'");
      if (req.method !== 'GET') { res.set('Allow', 'GET'); return page(res, 405, 'Método não permitido.'); }
      const query = req.query ?? {};
      if (Object.keys(query).length === 0) return page(res, 200, 'Endereço de retorno disponível. Inicie a conexão pelo painel administrativo do aplicativo.');
      if (query.result === 'received' && Object.keys(query).length === 1) {
        return page(res, 200, 'Autorização recebida. Consulte o status em Integração Bling no aplicativo.');
      }
      const state = query.start ?? query.state;
      if (!stateValid(state)) return page(res, 400, 'Solicitação inválida. Inicie a conexão pelo aplicativo.');
      const hash = digest(state);
      const ref = db.doc(`bling_oauth_sessions/${hash}`);
      let consumed = false;
      try {
        const initial = (await ref.get()).data();
        if (!initial || initial.expiresAt.toMillis() <= Date.now()) throw new Error('Expired');
        await sessionAdmin(initial.uid);
        if (query.start) {
          const credentials = await readCredentials();
          const nonce = randomBytes(32).toString('hex');
          await db.runTransaction(async tx => {
            const session = (await tx.get(ref)).data();
            if (!session || session.status !== 'pending' || session.expiresAt.toMillis() <= Date.now()) throw new Error('Used');
            tx.update(ref, {status: 'started', browserHash: digest(nonce)});
          });
          res.set('Set-Cookie', `${cookieName}=${nonce}; Max-Age=600; ${cookieOptions}`);
          const url = new URL('https://www.bling.com.br/Api/v3/oauth/authorize');
          url.search = new URLSearchParams({response_type: 'code', client_id: credentials.clientId,
            state, redirect_uri: BLING_CALLBACK_URL}).toString();
          return res.redirect(303, url.toString());
        }
        const nonce = (req.get('cookie') ?? '').split(';').map(value => value.trim())
          .find(value => value.startsWith(`${cookieName}=`))?.slice(cookieName.length + 1);
        if (!stateValid(nonce) || typeof initial.browserHash !== 'string' ||
            !timingSafeEqual(Buffer.from(digest(nonce)), Buffer.from(initial.browserHash))) throw new Error('Browser mismatch');
        await db.runTransaction(async tx => {
          const session = (await tx.get(ref)).data();
          if (!session || session.status !== 'started' || session.expiresAt.toMillis() <= Date.now()) throw new Error('Used');
          tx.update(ref, {status: 'consumed'});
        });
        consumed = true;
        res.set('Set-Cookie', `${cookieName}=; Max-Age=0; ${cookieOptions}`);
        if (query.error) return page(res, 400, 'A autorização não foi concluída. Você pode iniciar uma nova conexão no aplicativo.');
        if (typeof query.code !== 'string' || !query.code || query.code.length > 4096) throw new Error('Invalid code');
        const tokens = await exchangeCode(query.code, await readCredentials());
        await sessionAdmin(initial.uid); // Revocation during the provider request must also win.
        await db.runTransaction(async tx => {
          const existing = await tx.get(connection);
          if ((existing.data()?.connectedAt?.toMillis() ?? null) !== (initial.previousConnection ?? null)) throw new Error('Connection changed');
          tx.set(connection, {accessToken: tokens.accessToken, refreshToken: tokens.refreshToken,
            expiresAt: Timestamp.fromMillis(Date.now() + tokens.expiresIn * 1000), scope: tokens.scope,
            connectedBy: initial.uid, connectedAt: FieldValue.serverTimestamp(), synchronizationEnabled: false});
        });
        return res.redirect(303, `${BLING_CALLBACK_URL}?result=received`);
      } catch (_) {
        return page(res, 400, 'Não foi possível concluir esta conexão. Retorne ao aplicativo e inicie uma nova autorização.');
      } finally {
        if (consumed) {
          await release(hash).catch(() => {});
          await ref.delete().catch(() => {});
        }
      }
    },
  };
}
