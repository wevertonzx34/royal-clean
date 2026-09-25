import {randomUUID} from 'node:crypto';
import {Timestamp, FieldValue} from 'firebase-admin/firestore';
import {HttpsError} from 'firebase-functions/v2/https';
import {readBlingCredentials, validateBlingTokens} from './bling.js';

const fail = (code, message) => { throw new HttpsError(code, message); };
const text = (value, limit = 250) => typeof value === 'string' ? value.slice(0, limit) : '';
const number = value => typeof value === 'number' && Number.isFinite(value) ? value : null;
export function sanitizeBlingRecord(kind, item) {
  if (!item || !Number.isSafeInteger(item.id) || item.id <= 0) {
    fail('data-loss', 'O Bling retornou um registro inválido.');
  }
  if (kind === 'products') return {id: String(item.id), name: text(item.nome),
    code: text(item.codigo, 100), price: number(item.preco), unit: text(item.unidade, 30),
    status: text(item.situacao, 30), stock: number(item.estoque?.saldoVirtualTotal)};
  return {id: String(item.id), code: String(item.numero ?? '').slice(0, 100),
    date: text(item.data, 10), total: number(item.total),
    status: Number.isSafeInteger(item.situacao?.id) ? String(item.situacao.id) : ''};
}

export function validateBlingQuery(input = {}) {
  const kind = input.kind ?? 'products';
  const page = input.page ?? 1;
  if (!['products', 'sales'].includes(kind) || !Number.isSafeInteger(page) || page < 1 || page > 10000) {
    fail('invalid-argument', 'Consulta inválida.');
  }
  const query = new URLSearchParams({pagina: String(page), limite: '25'});
  if (kind === 'sales') {
    const validDate = value => typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value) &&
      Number.isFinite(Date.parse(value)) && new Date(value).toISOString().slice(0, 10) === value;
    if (!validDate(input.start) || !validDate(input.end) || input.start > input.end ||
        Date.parse(input.end) - Date.parse(input.start) > 366 * 86400000) {
      fail('invalid-argument', 'Selecione um período válido de até um ano.');
    }
    query.set('dataInicial', input.start);
    query.set('dataFinal', input.end);
  }
  return {kind, page, path: `${kind === 'products' ? 'produtos' : 'pedidos/vendas'}?${query}`};
}

export function createBlingDataHandler({db, authenticated, requireAdmin, rateLimit,
  readCredentials = readBlingCredentials, fetchImpl = (...args) => fetch(...args)}) {
  const ref = db.doc('integrations_private/bling');
  async function accessToken() {
    let data = (await ref.get()).data();
    if (!data) fail('failed-precondition', 'Conecte sua conta Bling primeiro.');
    if (data.reauthorizationRequired) fail('failed-precondition', 'Renove a autorização do Bling na tela de integração.');
    if (data.expiresAt?.toMillis() > Date.now() + 60000) return data.accessToken;
    const lock = randomUUID();
    const creds = await readCredentials();
    const needsRefresh = await db.runTransaction(async tx => {
      data = (await tx.get(ref)).data();
      if (!data || data.reauthorizationRequired) fail('failed-precondition', 'Renove a autorização do Bling.');
      if (data.expiresAt?.toMillis() > Date.now() + 60000) return false;
      if (data.refreshLock) fail('unavailable', 'A conexão está sendo renovada. Tente novamente em alguns instantes.');
      tx.update(ref, {refreshLock: lock, refreshStartedAt: FieldValue.serverTimestamp()});
      return true;
    });
    if (!needsRefresh) return data.accessToken;
    try {
      const response = await fetchImpl('https://api.bling.com.br/Api/v3/oauth/token', {
        method: 'POST', redirect: 'error', signal: AbortSignal.timeout(15000),
        headers: {'Content-Type': 'application/x-www-form-urlencoded', 'enable-jwt': '1',
          Authorization: `Basic ${Buffer.from(`${creds.clientId}:${creds.clientSecret}`).toString('base64')}`},
        body: new URLSearchParams({grant_type: 'refresh_token', refresh_token: data.refreshToken}),
      });
      if (!response.ok) throw new Error('Refresh failed');
      const token = validateBlingTokens(await response.json());
      await db.runTransaction(async tx => {
        const current = (await tx.get(ref)).data();
        if (current?.refreshLock !== lock) fail('aborted', 'A autorização mudou. Atualize a consulta.');
        tx.update(ref, {accessToken: token.accessToken, refreshToken: token.refreshToken,
          expiresAt: Timestamp.fromMillis(Date.now() + token.expiresIn * 1000),
          refreshLock: FieldValue.delete(), refreshStartedAt: FieldValue.delete()});
      });
      return token.accessToken;
    } catch (_) {
      // A timeout may already have rotated the provider token. Never replay it.
      await db.runTransaction(async tx => {
        const current = (await tx.get(ref)).data();
        if (current?.refreshLock === lock) tx.update(ref, {reauthorizationRequired: true, refreshLock: FieldValue.delete()});
      });
      fail('failed-precondition', 'Não foi possível renovar a conexão. Renove a autorização do Bling.');
    }
  }
  return async request => {
    const user = await authenticated(request);
    await requireAdmin(user);
    await rateLimit(user.uid, 'bling_data', 30);
    const {kind, page, path} = validateBlingQuery(request.data);
    const token = await accessToken();
    let response;
    try {
      response = await fetchImpl(`https://api.bling.com.br/Api/v3/${path}`, {
        headers: {Authorization: `Bearer ${token}`, Accept: 'application/json', 'enable-jwt': '1'},
        redirect: 'error', signal: AbortSignal.timeout(15000),
      });
    } catch (_) { fail('unavailable', 'O Bling não respondeu. Tente novamente.'); }
    if (response.status === 403) fail('permission-denied', kind === 'sales'
      ? 'Habilite a visualização de Pedidos de Venda no Bling e renove a autorização na tela de integração.'
      : 'Habilite a visualização de Produtos no Bling e renove a autorização.');
    if (response.status === 401) {
      // Do not overwrite a newer authorization or renewal.
      await db.runTransaction(async tx => {
        if ((await tx.get(ref)).data()?.accessToken === token) tx.update(ref, {reauthorizationRequired: true});
      });
      fail('failed-precondition', 'A autorização expirou ou foi revogada. Renove a autorização do Bling.');
    }
    if (response.status === 429) fail('resource-exhausted', 'O Bling limitou as consultas. Aguarde um minuto.');
    if (!response.ok) fail('unavailable', 'Consulta indisponível no Bling. Tente novamente.');
    const payload = await response.json();
    if (!Array.isArray(payload.data)) fail('data-loss', 'Resposta inesperada do Bling.');
    const items = payload.data.map(item => sanitizeBlingRecord(kind, item));
    await requireAdmin(await authenticated(request));
    const checkedAt = new Date().toISOString();
    // Private mirror only. Never expose sales or unreviewed prices in the public preview.
    const batch = db.batch();
    for (const item of items) batch.set(db.doc(`bling_private_${kind}/${item.id}`), {...item, checkedAt});
    batch.set(db.doc(`integrations_private/bling_last_${kind}`), {checkedAt, page, count: items.length});
    await batch.commit();
    return {kind, page, items, hasMore: items.length === 25, checkedAt, source: 'Bling'};
  };
}
