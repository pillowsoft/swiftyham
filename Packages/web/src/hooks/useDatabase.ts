/**
 * sql.js database hook — initializes WASM SQLite, runs migrations,
 * persists to IndexedDB, and provides QSORepository.
 */

import { useEffect, useRef, useState } from 'react';
import initSqlJs, { type Database } from 'sql.js';
import { MIGRATIONS } from '@hamstation/shared/src/db/schema';
import { QSORepository, type DatabaseDriver } from '@hamstation/shared/src/db/repository';

const DB_NAME = 'hamstation-pro';
const IDB_KEY = 'hamstation-db';

/** Wrap sql.js Database to match our DatabaseDriver interface. */
function wrapSqlJs(db: Database): DatabaseDriver {
  return {
    run(sql: string, params?: any[]) {
      db.run(sql, params);
    },
    exec(sql: string) {
      return db.exec(sql);
    },
    get(sql: string, params?: any[]) {
      const stmt = db.prepare(sql);
      if (params) stmt.bind(params);
      if (stmt.step()) {
        const row = stmt.getAsObject();
        stmt.free();
        return row;
      }
      stmt.free();
      return null;
    },
    all(sql: string, params?: any[]) {
      const stmt = db.prepare(sql);
      if (params) stmt.bind(params);
      const rows: any[] = [];
      while (stmt.step()) {
        rows.push(stmt.getAsObject());
      }
      stmt.free();
      return rows;
    },
  };
}

/** Save database to IndexedDB. */
async function saveToIndexedDB(db: Database): Promise<void> {
  const data = db.export();
  const buffer = new Uint8Array(data);

  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, 1);
    request.onupgradeneeded = () => {
      const idb = request.result;
      if (!idb.objectStoreNames.contains('databases')) {
        idb.createObjectStore('databases');
      }
    };
    request.onsuccess = () => {
      const tx = request.result.transaction('databases', 'readwrite');
      tx.objectStore('databases').put(buffer, IDB_KEY);
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    };
    request.onerror = () => reject(request.error);
  });
}

/** Load database from IndexedDB. */
async function loadFromIndexedDB(): Promise<Uint8Array | null> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, 1);
    request.onupgradeneeded = () => {
      const idb = request.result;
      if (!idb.objectStoreNames.contains('databases')) {
        idb.createObjectStore('databases');
      }
    };
    request.onsuccess = () => {
      const tx = request.result.transaction('databases', 'readonly');
      const getReq = tx.objectStore('databases').get(IDB_KEY);
      getReq.onsuccess = () => resolve(getReq.result || null);
      getReq.onerror = () => reject(getReq.error);
    };
    request.onerror = () => reject(request.error);
  });
}

export interface DatabaseContext {
  db: DatabaseDriver;
  repo: QSORepository;
  save: () => Promise<void>;
  isReady: boolean;
}

export function useDatabase(): DatabaseContext | null {
  const [ctx, setCtx] = useState<DatabaseContext | null>(null);
  const dbRef = useRef<Database | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function init() {
      // Load sql.js WASM from CDN
      const SQL = await initSqlJs({
        locateFile: (file: string) => `https://cdnjs.cloudflare.com/ajax/libs/sql.js/1.12.0/${file}`,
      });

      // Try loading from IndexedDB
      const saved = await loadFromIndexedDB();
      const db = saved ? new SQL.Database(saved) : new SQL.Database();
      dbRef.current = db;

      const driver = wrapSqlJs(db);

      // Run migrations
      for (const migration of MIGRATIONS) {
        // Check if already applied
        try {
          const result = driver.get('SELECT version FROM schema_version WHERE version = ?', [migration.version]);
          if (result) continue;
        } catch {
          // schema_version doesn't exist yet
        }

        // Split multi-statement SQL and run each
        const statements = migration.sql.split(';').map(s => s.trim()).filter(s => s.length > 0);
        for (const stmt of statements) {
          driver.run(stmt);
        }
      }

      const repo = new QSORepository(driver);
      repo.ensureDefaultLogbook();

      const save = async () => {
        if (dbRef.current) await saveToIndexedDB(dbRef.current);
      };

      if (!cancelled) {
        setCtx({ db: driver, repo, save, isReady: true });
      }
    }

    init().catch(console.error);

    return () => { cancelled = true; };
  }, []);

  return ctx;
}
