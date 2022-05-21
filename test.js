const http = require('http');

http.get('http://localhost:8081')
    .on('response', response => {
        let body = '';
        response.on('data', chunk => body += chunk.toString('utf8'));
        response.on('end', () => {
            if (body.includes('<title>Admin</title>')) {
                console.log('ioBroker admin is running');
                process.exit(0);
            } else {
                console.error('ioBroker admin is NOT running');
                process.exit(1);
            }
        });
    })
    .on('error', () => {
        console.log('Cannot reach localhost:8081');
        process.exit(1);
    });