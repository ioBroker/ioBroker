const http = require('node:http');

function checkAdmin() {
    return new Promise(resolve => http.get('http://localhost:8081')
        .on('response', response => {
            let body = '';
            response.on('data', chunk => body += chunk.toString('utf8'));
            response.on('end', () => {
                if (body.includes('<title>Admin</title>')) {
                    console.log('ioBroker admin is running');
                    resolve(true);
                } else {
                    console.error('ioBroker admin is NOT running');
                    resolve(false);
                }
            });
        })
        .on('error', () => {
            console.log('Cannot reach localhost:8081');
            resolve(false);
        }));
}

function wait() {
    return new Promise(resolve => setTimeout(() => resolve(), 5000));
}

async function test() {
    for (let i = 0; i < 10; i++) {
        let result = await checkAdmin();
        if (result) {
            process.exit(0);
        }
        await wait();
    }
    process.exit(1);
}

test();
