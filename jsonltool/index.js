#!/usr/bin/env node

const { JsonlDB } = require('@alcalzone/jsonl-db');
const fs = require('fs');
const path = require('path');

async function compressDB(dbPath) {
    const db = new JsonlDB(dbPath);
    await db.open();
    await db.compress();
    await db.close();
}

async function main() {
    let dbPath = process.argv[2];
    if (!dbPath) {
        dbPath = process.cwd();
        console.log(`No path given, using ${dbPath}`);
    }
    const statesFile = path.join(dbPath, 'states.jsonl');
    try {
        if (fs.existsSync(statesFile)) {
            console.log(`Compressing ${statesFile}`);
            await compressDB(statesFile);
        } else {
            console.log('states.jsonl not found to compress, skip');
        }
    } catch (e) {
        console.log(`Cannot compress states.jsonl: ${e.stack}`);
    }
    const objectsFile = path.join(dbPath, 'objects.jsonl');
    try {
        if (fs.existsSync(objectsFile)) {
            console.log(`Compressing ${objectsFile}`);
            await compressDB(objectsFile);
        } else {
            console.log('objects.jsonl not found to compress, skip');
        }
    } catch (e) {
        console.log(`Cannot compress objects.jsonl: ${e.stack}`);
    }
}

main().then(() => process.exit(1)).catch(e => {});
