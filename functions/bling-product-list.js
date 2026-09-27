import {HttpsError} from 'firebase-functions/v2/https';

export function validateProductCatalog(input) {
  const page = input.page ?? 1;
  if (!Number.isSafeInteger(page) || page < 1 || page > 10000 ||
      (input.catalogRun !== undefined && (typeof input.catalogRun !== 'string' || input.catalogRun.length > 100))) {
    throw new HttpsError('invalid-argument', 'Página de produtos inválida.');
  }
  return {kind: 'productCatalog', page, path: null};
}

export async function readProductCatalog(db, input) {
  const complete = (await db.doc('integrations_private/bling_product_catalog').get()).data()?.complete;
  if (!complete) throw new HttpsError('failed-precondition', 'Aguarde a sincronização completa dos produtos.');
  if (input.catalogRun && input.catalogRun !== complete.runId) {
    throw new HttpsError('aborted', 'A base de produtos mudou. Atualize a lista.');
  }
  const snapshot = await db.collection(`bling_catalog_snapshots/${complete.slot}/products`)
    .where('catalogRun', '==', complete.runId)
    .select('name', 'code', 'price', 'unit', 'status', 'stock').get();
  // Same population as the current dashboard: excluded products are not counted.
  const rows = snapshot.docs.map(doc => ({id: doc.id, ...doc.data()})).filter(r => r.status !== 'E');
  const expected = ['A', 'I', '?'].reduce((n, status) => n + (complete.counts[status] ?? 0), 0);
  if (rows.length !== expected) throw new HttpsError('data-loss', 'Catálogo incompleto. A última lista foi preservada.');
  rows.sort((a, b) => (a.name ?? '').localeCompare(b.name ?? '', 'pt-BR') || a.id.localeCompare(b.id));
  const page = input.page ?? 1, offset = (page - 1) * 100;
  return {items: rows.slice(offset, offset + 100), total: rows.length, page,
    hasMore: offset + 100 < rows.length, catalogRun: complete.runId, checkedAt: complete.checkedAt};
}
