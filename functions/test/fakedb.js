// Minimal in-memory Firestore for admin tests: where (==,>,<,>=), orderBy, limit,
// doc get/set/update/delete, add. Timestamps are plain Dates / "TS" markers.
function makeDb(seed = {}) {
  const store = structuredClone(seed);
  let n = 0;
  const val = (x) => (x instanceof Date ? x.getTime() : x);
  const cmp = (d, [f, op, v]) => {
    const x = val(d[f]);
    const y = val(v);
    return { "==": x === y, ">": x > y, "<": x < y, ">=": x >= y }[op];
  };
  const col = (name) => {
    store[name] = store[name] || {};
    const make = (filters, order, lim) => ({
      where: (f, op, v) => make([...filters, [f, op, v]], order, lim),
      orderBy: (f, dir = "asc") => make(filters, [f, dir], lim),
      limit: (l) => make(filters, order, l),
      get: async () => {
        let rows = Object.entries(store[name]).filter(([, d]) => filters.every((f) => cmp(d, f)));
        if (order) {
          rows.sort(([, a], [, b]) =>
            (val(a[order[0]]) > val(b[order[0]]) ? 1 : -1) * (order[1] === "desc" ? -1 : 1));
        }
        if (lim) rows = rows.slice(0, lim);
        return {
          empty: !rows.length,
          docs: rows.map(([id, d]) => ({
            id, data: () => d,
            ref: {
              update: async (u) => Object.assign(store[name][id], u),
              delete: async () => { delete store[name][id]; },
            },
          })),
        };
      },
    });
    return {
      ...make([], null, 0),
      doc: (id) => ({
        get: async () => ({ exists: id in store[name], id, data: () => store[name][id] }),
        set: async (d, o) => { store[name][id] = o && o.merge ? { ...(store[name][id] || {}), ...d } : d; },
        update: async (u) => Object.assign(store[name][id], u),
        delete: async () => { delete store[name][id]; },
      }),
      add: async (d) => { const id = `${name}_auto${++n}`; store[name][id] = d; return { id }; },
    };
  };
  return { db: { collection: col }, store };
}
module.exports = { makeDb };
