#!/usr/bin/env node

const { JsonlDB } = require('@alcalzone/jsonl-db');
const fs = require('fs');
const path = require('path');

async function compressDB(path) {
    const db = new JsonlDB(path);
    await db.open();
    await db.compress();
    await db.close();
}

async function main() {
    let path = process.argv[2];
    if (!path) {
        path = process.cwd();
        console.log(`No path given, using ${path}`);
    }
    const statesFile = path.join(path, 'states.jsonl');
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
    const objectsFile = path.join(path, 'objects.jsonl');
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
