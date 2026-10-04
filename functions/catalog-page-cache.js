// Reuse a complete, sorted generation while its pages are downloaded.
// Authorization and generation checks remain in the callable on EVERY request.
const databases = new WeakMap();
const ttl = 60000, budget = 8 * 1024 * 1024;

export async function catalogPageRows(db, key, load, {fresh = false} = {}) {
  let cache = databases.get(db);
  if (!cache) { cache = new Map(); databases.set(db, cache); }
  const now = Date.now();
  for (const [name, entry] of cache) if (entry.expires <= now) cache.delete(name);
  const prior = cache.get(key);
  if (prior && (!fresh || prior.pending)) return prior.promise;
  const entry = {expires: now + ttl, pending: true, bytes: 0};
  entry.promise = Promise.resolve().then(load).then(rows => {
    entry.pending = false;
    entry.bytes = Buffer.byteLength(JSON.stringify(rows));
    if (entry.bytes > budget) {
      if (cache.get(key) === entry) cache.delete(key);
    } else {
      let bytes = [...cache.values()].reduce((sum, value) => sum + value.bytes, 0);
      for (const [name, value] of cache) {
        if (bytes <= budget && cache.size <= 3) break;
        if (value !== entry) { cache.delete(name); bytes -= value.bytes; }
      }
    }
    return rows;
  }, error => {
    if (cache.get(key) === entry) cache.delete(key);
    throw error;
  });
  cache.set(key, entry);
  return entry.promise;
}

export function catalogPageSize(input, fallback) {
  const size = input.pageSize ?? fallback;
  if (!Number.isSafeInteger(size) || size < 25 || size > 250) return null;
  return size;
}
