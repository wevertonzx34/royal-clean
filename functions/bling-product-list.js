import {liveCatalogRows, catalogRevision, catalogCheckedAt} from './bling-live-sync.js';
import {HttpsError} from 'firebase-functions/v2/https';
import {catalogPageRows, catalogPageSize} from './catalog-page-cache.js';

export function validateProductCatalog(input) {
  const page = input.page ?? 1;
  if (!catalogPageSize(input, 100) || !Number.isSafeInteger(page) || page < 1 || page > 10000 ||
      (input.catalogRun !== undefined && (typeof input.catalogRun !== 'string' || input.catalogRun.length > 100))) {
    throw new HttpsError('invalid-argument', 'Página de produtos inválida.');
  }
  return {kind: 'productCatalog', page, path: null};
}

export async function readProductCatalog(db, input) {
  const complete = (await db.doc('integrations_private/bling_product_catalog').get()).data()?.complete;
  if (!complete) throw new HttpsError('failed-precondition', 'Aguarde a sincronização completa dos produtos.');
  const revision=await catalogRevision(db,'products',complete);
  if (input.catalogRun && input.catalogRun !== revision) {
    throw new HttpsError('aborted', 'A base de produtos mudou. Atualize a lista.');
  }
  const rows = await catalogPageRows(db, `products:${revision}`, async () => {
  const snapshot = await db.collection(`bling_catalog_snapshots/${complete.slot}/products`)
    .where('catalogRun', '==', complete.runId)
    .select('name', 'code', 'price', 'unit', 'status', 'stock','detailsCheckedAt').get();
  // Same population as the current dashboard: excluded products are not counted.
  const baseRows = snapshot.docs.map(doc => ({id: doc.id, ...doc.data()}));
  const rows=(await liveCatalogRows(db,'products',complete,baseRows)).filter(r=>r.status!=='E');
  const expected = ['A', 'I', '?'].reduce((n, status) => n + (complete.counts[status] ?? 0), 0);
  if (baseRows.filter(r=>r.status!=='E').length !== expected) throw new HttpsError('data-loss', 'Catálogo incompleto. A última lista foi preservada.');
  rows.sort((a, b) => (a.name ?? '').localeCompare(b.name ?? '', 'pt-BR') || a.id.localeCompare(b.id));
  return rows;
  }, {fresh: (input.page ?? 1) === 1});
  const size = catalogPageSize(input, 100);
  const page = input.page ?? 1, offset = (page - 1) * size;
  if(revision!==await catalogRevision(db,'products',complete))throw new HttpsError('aborted','Base atualizada durante a consulta.');
  return {items: rows.slice(offset, offset + size), total: rows.length, page,
    hasMore: offset + size < rows.length, catalogRun: revision, checkedAt:await catalogCheckedAt(db,'products',complete)};
}
