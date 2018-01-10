/* jshint -W097 */// jshint strict:false
/*jslint node: true */
var expect = require('chai').expect;
var path = require('path');
var request = require('request');

describe('Test running Admin on port 8081', function() {
    it('Test 8081', function (done) {
        request('http://127.0.0.1:8081/', function (error, response, body) {
            console.log('BODY: ' + body);
            expect(error).to.be.not.ok;
            expect(body.indexOf('<title>ioBroker.admin</title>')).to.be.not.equal(-1);
            expect(response.statusCode).to.equal(200);
            done();
        });
    });

});
