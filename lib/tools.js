// @ts-check
'use strict';

const fs = require('fs');
const semver = require('semver');
const path = require('path');
let request;
let extend;

function rmdirRecursiveSync(path) {
    if (fs.existsSync(path)) {
        fs.readdirSync(path).forEach(function (file, index) {
            const curPath = path + '/' + file;
            if (fs.statSync(curPath).isDirectory()) {
                // recurse
                rmdirRecursiveSync(curPath);
            } else {
                // delete file
                fs.unlinkSync(curPath);
            }
        });
        // delete (hopefully) empty folder
        try {
            fs.rmdirSync(path);
        } catch (e) {
            console.log('Cannot delete directory ' + path + ': ' + e.toString());
        }
    }
}

function findIPs() {
    const ifaces = require('os').networkInterfaces();
    const ipArr = [];
    for (const dev in ifaces) {
        if (ifaces.hasOwnProperty(dev)) {
            /*jshint loopfunc:true */
            ifaces[dev].forEach(function (details) {
                if (!details.internal) ipArr.push(details.address);
            });
        }
    }
    return ipArr;
}

function findPath(path, url) {
    if (!url) return '';
    if (url.substring(0, 'http://'.length) === 'http://' ||
        url.substring(0, 'https://'.length) === 'https://') {
        return url;
    } else {
        if (path.substring(0, 'http://'.length) === 'http://' ||
            path.substring(0, 'https://'.length) === 'https://') {
            return (path + url).replace(/\/\//g, '/').replace('http:/', 'http://').replace('https:/', 'https://');
        } else {
            if (url && url[0] === '/') {
                return __dirname + '/..' + url;
            } else {
                return __dirname + '/../' + path + url;
            }
        }
    }
}

// Download file to tmp or return file name directly
function getFile(urlOrPath, fileName, callback) {
    if (!request) request = require('request');

    // If object was read
    if (urlOrPath.substring(0, 'http://'.length) === 'http://' ||
        urlOrPath.substring(0, 'https://'.length) === 'https://') {
        const tmpFile = __dirname + '/../tmp/' + (fileName || Math.floor(Math.random() * 0xFFFFFFE) + '.zip');
        request(urlOrPath).on('error', function (/* error */) {
            console.log('Cannot download  ' + tmpFile);
            if (callback) callback(tmpFile);
        }).pipe(fs.createWriteStream(tmpFile)).on('close', function () {
            console.log('downloaded ' + tmpFile);
            if (callback) callback(tmpFile);
        });
    } else {
        if (fs.existsSync(urlOrPath)) {
            if (callback) callback(urlOrPath);
        } else if (fs.existsSync(__dirname + '/../' + urlOrPath)) {
            if (callback) callback(__dirname + '/../' + urlOrPath);
        } else if (fs.existsSync(__dirname + '/../tmp/' + urlOrPath)) {
            if (callback) callback(__dirname + '/../tmp/' + urlOrPath);
        } else if (fs.existsSync(__dirname + '/../adapter/' + urlOrPath)) {
            if (callback) callback(__dirname + '/../adapter/' + urlOrPath);
        } else {
            console.log('File not found: ' + urlOrPath);
            process.exit(1);
        }
    }
}

// Return content of the json file. Download it or read directly
function getJson(urlOrPath, callback) {
    if (!request) request = require('request');
    let sources = {};
    // If object was read
    if (urlOrPath && typeof urlOrPath === 'object') {
        if (callback) callback(urlOrPath);
    } else if (!urlOrPath) {
        console.log('Empty url!');
        if (callback) callback(null);
    } else {
        if (urlOrPath.substring(0, 'http://'.length) === 'http://' ||
            urlOrPath.substring(0, 'https://'.length) === 'https://') {
            request({ url: urlOrPath, timeout: 5000 }, function (error, response, body) {
                if (error || !body || response.statusCode !== 200) {
                    console.log('Cannot download json from ' + urlOrPath + '. Error: ' + (error || body));
                    if (callback) callback(null, urlOrPath);
                    return;
                }
                try {
                    sources = JSON.parse(body);
                } catch (e) {
                    console.log('Json file is invalid on ' + urlOrPath);
                    if (callback) callback(null, urlOrPath);
                    return;
                }

                if (callback) callback(sources, urlOrPath);
            }).on('error', function (error) {
                //console.log('Cannot download json from ' + urlOrPath + '. Error: ' + error);
                //if (callback) callback(null, urlOrPath);
            });
        } else {
            if (fs.existsSync(urlOrPath)) {
                try {
                    sources = JSON.parse(fs.readFileSync(urlOrPath, 'utf8'));
                } catch (e) {
                    console.log('Cannot parse json file from ' + urlOrPath + '. Error: ' + e);
                    if (callback) callback(null, urlOrPath);
                    return;
                }
                if (callback) callback(sources, urlOrPath);
            } else if (fs.existsSync(__dirname + '/../' + urlOrPath)) {
                try {
                    sources = JSON.parse(fs.readFileSync(__dirname + '/../' + urlOrPath, 'utf8'));
                } catch (e) {
                    console.log('Cannot parse json file from ' + __dirname + '/../' + urlOrPath + '. Error: ' + e);
                    if (callback) callback(null, urlOrPath);
                    return;
                }
                if (callback) callback(sources, urlOrPath);
            } else if (fs.existsSync(__dirname + '/../tmp/' + urlOrPath)) {
                try {
                    sources = JSON.parse(fs.readFileSync(__dirname + '/../tmp/' + urlOrPath, 'utf8'));
                } catch (e) {
                    console.log('Cannot parse json file from ' + __dirname + '/../tmp/' + urlOrPath + '. Error: ' + e);
                    if (callback) callback(null, urlOrPath);
                    return;
                }
                if (callback) callback(sources, urlOrPath);
            } else if (fs.existsSync(__dirname + '/../adapter/' + urlOrPath)) {
                try {
                    sources = JSON.parse(fs.readFileSync(__dirname + '/../adapter/' + urlOrPath, 'utf8'));
                } catch (e) {
                    console.log('Cannot parse json file from ' + __dirname + '/../adapter/' + urlOrPath + '. Error: ' + e);
                    if (callback) callback(null, urlOrPath);
                    return;
                }
                if (callback) callback(sources, urlOrPath);
            } else {
                //if (urlOrPath.indexOf('/example/') === -1) console.log('Json file not found: ' + urlOrPath);
                if (callback) callback(null, urlOrPath);
            }
        }
    }
}

// Get list of all installed adapters and controller version on this host
function getInstalledInfo(hostRunningVersion) {
    const result = {};
    let path = __dirname + '/../';
    // Get info about host
    let ioPackage = JSON.parse(fs.readFileSync(path + 'io-package.json', 'utf8'));
    let pack = fs.existsSync(path + 'package.json') ? JSON.parse(fs.readFileSync(path + 'package.json', 'utf8')) : {};
    result[ioPackage.common.name] = {
        controller: true,
        version: ioPackage.common.version,
        icon: ioPackage.common.extIcon || ioPackage.common.icon,
        title: ioPackage.common.title,
        desc: ioPackage.common.desc,
        platform: ioPackage.common.platform,
        keywords: ioPackage.common.keywords,
        readme: ioPackage.common.readme,
        runningVersion: hostRunningVersion,
        license: ioPackage.common.license ? ioPackage.common.license : ((pack.licenses && pack.licenses.length) ? pack.licenses[0].type : ''),
        licenseUrl: (pack.licenses && pack.licenses.length) ? pack.licenses[0].url : ''
    };
    let dirs = fs.readdirSync(__dirname + '/../adapter');
    for (let i = 0; i < dirs.length; i++) {
        try {
            path = __dirname + '/../adapter/' + dirs[i] + '/';
            if (fs.existsSync(path + 'io-package.json')) {
                ioPackage = JSON.parse(fs.readFileSync(path + 'io-package.json', 'utf8'));
                pack = fs.existsSync(path + 'package.json') ? JSON.parse(fs.readFileSync(path + 'package.json', 'utf8')) : {};
                result[ioPackage.common.name] = {
                    controller: false,
                    version: ioPackage.common.version,
                    icon: ioPackage.common.extIcon || (ioPackage.common.icon ? '/adapter/' + dirs[i] + '/' + ioPackage.common.icon : ''),
                    title: ioPackage.common.title,
                    desc: ioPackage.common.desc,
                    platform: ioPackage.common.platform,
                    keywords: ioPackage.common.keywords,
                    readme: ioPackage.common.readme,
                    type: ioPackage.common.type,
                    license: ioPackage.common.license ? ioPackage.common.license : ((pack.licenses && pack.licenses.length) ? pack.licenses[0].type : ''),
                    licenseUrl: (pack.licenses && pack.licenses.length) ? pack.licenses[0].url : ''
                };
            }
        } catch (e) {
            console.log('Cannot read or parse ' + __dirname + '/../adapter/' + dirs[i] + '/io-package.json: ' + e.toString());
        }
    }
    dirs = fs.readdirSync(__dirname + '/../node_modules');
    for (let i = 0; i < dirs.length; i++) {
        try {
            path = __dirname + '/../node_modules/' + dirs[i] + '/';
            if (dirs[i].match(/^iobroker\./i) && fs.existsSync(path + 'io-package.json')) {
                ioPackage = JSON.parse(fs.readFileSync(path + 'io-package.json', 'utf8'));
                pack = fs.existsSync(path + 'package.json') ? JSON.parse(fs.readFileSync(path + 'package.json', 'utf8')) : {};
                result[ioPackage.common.name] = {
                    controller: false,
                    version: ioPackage.common.version,
                    icon: ioPackage.common.extIcon || (ioPackage.common.icon ? '/adapter/' + dirs[i] + '/' + ioPackage.common.icon : ''),
                    title: ioPackage.common.title,
                    desc: ioPackage.common.desc,
                    platform: ioPackage.common.platform,
                    keywords: ioPackage.common.keywords,
                    readme: ioPackage.common.readme,
                    type: ioPackage.common.type,
                    license: ioPackage.common.license ? ioPackage.common.license : ((pack.licenses && pack.licenses.length) ? pack.licenses[0].type : ''),
                    licenseUrl: (pack.licenses && pack.licenses.length) ? pack.licenses[0].url : ''
                };
            }
        } catch (e) {
            console.log('Cannot read or parse ' + __dirname + '/../node_modules/' + dirs[i] + '/io-package.json: ' + e.toString());
        }
    }
    if (fs.existsSync(__dirname + '/../../../node_modules/iobroker.js-controller') ||
        fs.existsSync(__dirname + '/../../../node_modules/ioBroker.js-controller')) {
        dirs = fs.readdirSync(__dirname + '/../..');
        for (let i = 0; i < dirs.length; i++) {
            try {
                path = __dirname + '/../../' + dirs[i] + '/';
                if (dirs[i].match(/^iobroker\./i) && dirs[i].substring('iobroker.'.length) !== 'js-controller' &&
                    fs.existsSync(path + 'io-package.json')) {
                    ioPackage = JSON.parse(fs.readFileSync(path + 'io-package.json', 'utf8'));
                    pack = fs.existsSync(path + 'package.json') ? JSON.parse(fs.readFileSync(path + 'package.json', 'utf8')) : {};
                    result[ioPackage.common.name] = {
                        controller: false,
                        version: ioPackage.common.version,
                        icon: ioPackage.common.extIcon || (ioPackage.common.icon ? '/adapter/' + dirs[i] + '/' + ioPackage.common.icon : ''),
                        title: ioPackage.common.title,
                        desc: ioPackage.common.desc,
                        platform: ioPackage.common.platform,
                        keywords: ioPackage.common.keywords,
                        readme: ioPackage.common.readme,
                        license: ioPackage.common.license ? ioPackage.common.license : ((pack.licenses && pack.licenses.length) ? pack.licenses[0].type : ''),
                        licenseUrl: (pack.licenses && pack.licenses.length) ? pack.licenses[0].url : ''
                    };
                }
            } catch (e) {
                console.log('Cannot read or parse ' + __dirname + '/../node_modules/' + dirs[i] + '/io-package.json: ' + e.toString());
            }
        }
    }
    return result;
}


/**
 * Reads an adapter's npm version
 * @param {string | null} adapter The adapter to read the npm version from. Null for the root ioBroker packet
 * @param {(err: Error | null, version?: string) => void} [callback]
 */
function getNpmVersion(adapter, callback) {
    adapter = adapter ? 'iobroker.' + adapter : 'iobroker';
    adapter = adapter.toLowerCase();

    const cliCommand = `npm view ${adapter}@latest version`;

    const exec = require('child_process').exec;
    exec(cliCommand, { timeout: 2000 }, (error, stdout, stderr) => {
        let version;
        if (error) {
            // command failed
            if (typeof callback === 'function') {
                callback(error);
                return;
            }
        } else if (stdout) {
            version = semver.valid(stdout.trim());
        }
        if (typeof callback === 'function') callback(null, version);
    });
}

function getIoPack(sources, name, callback) {
    getJson(sources[name].meta, function (ioPack) {
        const packUrl = sources[name].meta.replace('io-package.json', 'package.json');
        getJson(packUrl, function (pack) {
            // If installed from git or something else
            // js-controller is exception, because can be installed from npm and from git
            if (sources[name].url && name !== 'js-controller') {
                if (ioPack && ioPack.common) {
                    sources[name] = extend(true, sources[name], ioPack.common);
                    if (pack && pack.licenses && pack.licenses.length) {
                        if (!sources[name].license) sources[name].license = pack.licenses[0].type;
                        if (!sources[name].licenseUrl) sources[name].licenseUrl = pack.licenses[0].url;
                    }
                }

                if (callback) callback(sources, name);
            } else {
                if (ioPack && ioPack.common) {
                    sources[name] = extend(true, sources[name], ioPack.common);
                    if (pack && pack.licenses && pack.licenses.length) {
                        if (!sources[name].license) sources[name].license = pack.licenses[0].type;
                        if (!sources[name].licenseUrl) sources[name].licenseUrl = pack.licenses[0].url;
                    }
                }

                if (sources[name].meta.substring(0, 'http://'.length) === 'http://' ||
                    sources[name].meta.substring(0, 'https://'.length) === 'https://') {
                    //installed from npm
                    getNpmVersion(name, function (err, version) {
                        if (version) sources[name].version = version;
                        if (callback) callback(sources, name);
                    });
                } else {
                    if (callback) callback(sources, name);
                }
            }
        });
    });
}

// Get list of all adapters and controller in some repository file or in /conf/source-dist.json
function getRepositoryFile(urlOrPath, callback) {
    let sources = {};
    let path = '';
    let toRead = 0;
    let timeout = null;
    let count = 0;

    if (!extend) extend = require('node.extend');

    if (urlOrPath) {
        const parts = urlOrPath.split('/');
        path = parts.splice(0, parts.length - 1).join('/') + '/';
    }

    // If object was read
    if (urlOrPath && typeof urlOrPath === 'object') {
        if (callback) callback(urlOrPath);
    } else if (!urlOrPath) {
        try {
            sources = JSON.parse(fs.readFileSync(__dirname + '/../conf/sources.json', 'utf8'));
        } catch (e) {
            sources = {};
        }
        try {
            const sourcesDist = JSON.parse(fs.readFileSync(__dirname + '/../conf/sources-dist.json', 'utf8'));
            sources = extend(true, sourcesDist, sources);
        } catch (e) {
            // Don't care
        }

        for (const name in sources) {
            if (sources[name].url) sources[name].url = findPath(path, sources[name].url);
            if (sources[name].meta) sources[name].meta = findPath(path, sources[name].meta);
            if (sources[name].icon) sources[name].icon = findPath(path, sources[name].icon);

            if (!sources[name].version && sources[name].meta) {
                toRead++;
                count++;
                getIoPack(sources, name, function (ignore, name) {
                    toRead--;
                    if (!toRead && timeout) {
                        clearTimeout(timeout);
                        if (callback) callback(sources);
                        timeout = null;
                        callback = null;
                    }
                });
            }
        }

        if (!toRead) {
            if (callback) callback(sources);
        } else {
            timeout = setTimeout(function () {
                if (timeout) {
                    console.log('Timeout by read all package.json (' + count + ') seconds');
                    clearTimeout(timeout);
                    if (callback) callback(sources);
                    timeout = null;
                    callback = null;
                }
            }, count * 500);
        }
    } else {
        getJson(urlOrPath, function (sources) {
            if (sources) {
                for (const name in sources) {
                    if (!sources.hasOwnProperty(name)) continue;
                    if (sources[name].url) sources[name].url = findPath(path, sources[name].url);
                    if (sources[name].meta) sources[name].meta = findPath(path, sources[name].meta);
                    if (sources[name].icon) sources[name].icon = findPath(path, sources[name].icon);

                    if (!sources[name].version && sources[name].meta) {
                        toRead++;
                        count++;
                        getIoPack(sources, name, function (ignore, name) {
                            toRead--;
                            if (!toRead && timeout) {
                                clearTimeout(timeout);
                                if (callback) callback(sources);
                                timeout = null;
                                callback = null;
                            }
                        });
                    }
                }
            }
            if (!toRead) {
                if (callback) callback(sources);
            } else {
                timeout = setTimeout(function () {
                    if (timeout) {
                        console.log('Timeout by read all package.json (' + count + ') seconds');
                        clearTimeout(timeout);
                        if (callback) callback(sources);
                        timeout = null;
                        callback = null;
                    }
                }, count * 500);
            }
        });
    }
}

function sendDiagInfo(obj, callback) {
    if (!request) request = require('request');
    request.post({
        url: 'http://download.iobroker.org/diag.php',
        method: 'POST',
        headers: { 'content-type': 'application/x-www-form-urlencoded' },
        body: 'data=' + JSON.stringify(obj),
        timeout: 2000
    }, function (err, response, body) {
        /*if (err || !body || response.statusCode !== 200) {

        }*/
    }).on('error', function (error) {
        console.log('Cannot send diag info: ' + error.message);
    });
}

function getAdapterDir(adapter, isNpm) {
    const parts = __dirname.replace(/\\/g, '/').split('/');
    parts.splice(parts.length - 3, 3);
    /** @type {string | string[]} */
    let dir = parts.join('/');
    if (adapter.substring(0, 'iobroker.'.length) === 'iobroker.') adapter = adapter.substring('iobroker.'.length);

    if (fs.existsSync(dir + '/node_modules/iobroker.js-controller') &&
        fs.existsSync(dir + '/node_modules/iobroker.' + adapter)) {
        dir = __dirname.replace(/\\/g, '/').split('/');
        dir.splice(dir.length - 2, 2);
        return dir.join('/') + '/iobroker.' + adapter;
    } else if (fs.existsSync(__dirname + '/../node_modules/iobroker.' + adapter)) {
        dir = __dirname.replace(/\\/g, '/').split('/');
        dir.splice(dir.length - 1, 1);
        return dir.join('/') + '/node_modules/iobroker.' + adapter;
    } else if (fs.existsSync(__dirname + '/../adapter/' + adapter)) {
        dir = __dirname.replace(/\\/g, '/').split('/');
        dir.splice(dir.length - 1, 1);
        return dir.join('/') + '/adapter/' + adapter;
    } else {
        if (isNpm) {
            if (fs.existsSync(__dirname + '/../../node_modules/iobroker.js-controller')) {
                dir = __dirname.replace(/\\/g, '/').split('/');
                dir.splice(dir.length - 2, 2);
                return dir.join('/') + '/iobroker.' + adapter;
            } else {
                dir = __dirname.replace(/\\/g, '/').split('/');
                dir.splice(dir.length - 1, 1);
                return dir.join('/') + '/node_modules/iobroker.' + adapter;
            }
        } else {
            dir = __dirname.replace(/\\/g, '/').split('/');
            dir.splice(dir.length - 1, 1);
            return dir.join('/') + '/adapter/' + adapter;
        }
    }
}
// All pathes are returned always relative to /node_modules/iobroker.js-controller
function getDefaultDataDir() {
    /** @type {string | string[]} */
    let dataDir = __dirname.replace(/\\/g, '/');
    dataDir = dataDir.split('/');

    // If installed with npm
    if (fs.existsSync(__dirname + '/../../../node_modules/iobroker.js-controller')) {
        return '../../iobroker-data/';
    } else {
        dataDir.splice(dataDir.length - 1, 1);
        dataDir = dataDir.join('/');
        return './data/';
    }
}

function getConfigFileName() {
    /** @type {string | string[]} */
    let configDir = __dirname.replace(/\\/g, '/');
    configDir = configDir.split('/');

    // If installed with npm
    if (fs.existsSync(__dirname + '/../../../node_modules/iobroker.js-controller') ||
        fs.existsSync(__dirname + '/../../../node_modules/ioBroker.js-controller')) {
        // remove /node_modules/ioBroker.js-controller/lib
        configDir.splice(configDir.length - 3, 3);
        configDir = configDir.join('/');
        return configDir + '/iobroker-data/iobroker.json';
    } else {
        // Remove /lib
        configDir.splice(configDir.length - 1, 1);
        configDir = configDir.join('/');
        if (fs.existsSync(__dirname + '/../conf/iobroker.json')) {
            return configDir + '/conf/iobroker.json';
        } else {
            return configDir + '/data/iobroker.json';
        }
    }
}

/**
 * Tests if we are currently inside a node_modules folder
 * @returns {boolean}
 */
function isThisInsideNodeModules() {
    return /[\\/]node_modules[\\/]/.test(__dirname);
}

/**
 * Recursively creates a directory if it doesn't exist
 * @param {string} dir The directory to create
 * @returns {boolean} true if it worked, false if not
 */
function mkdirRecursiveSync(dir) {
    // Build a list of all directories from the root up the the given one
    // e.g. /opt/iobroker/foo => ['/', '/opt', '/opt/iobroker', '/opt/iobroker/foo']
    const parts = dir.split(path.sep);
    const directories = parts.reduce((acc, cur) => {
        if (acc.length) {
            acc.push(path.join(acc[acc.length - 1], cur));
        } else { // first entry
            // On unix, we need to use the path separator as the first item
            acc.push(cur != '' ? cur : path.sep);
        }
        return acc;
    }, []);
    // Ensure all of those exist
    try {
        for (const partialDir of directories) {
            // On Unix, the first item is the empty path '' which we cannot create
            if (partialDir === '') continue;
            console.log(`mkdirRecursiveSync: creating ${partialDir}`);
            if (!fs.existsSync(partialDir)) fs.mkdirSync(partialDir);
        }
        return true;
    } catch (e) {
        console.error(e);
        return false;
    }
}

/**
 * Recursively enumerates all files in the given directory
 * @param {string} dir The directory to scan
 * @param {(name: string) => boolean} [predicate] An optional predicate to apply to every found file system entry
 * @returns {string[]} A list of all files found
 */
function enumFilesRecursiveSync(dir, predicate) {
    const ret = [];
    if (typeof predicate !== 'function') predicate = () => true;
    // enumerate all files in this directory
    const filesOrDirs = fs.readdirSync(dir)
        .filter(predicate) // exclude all files starting with "."
        .map(f => path.join(dir, f)) // and prepend the full path
        ;
    for (const entry of filesOrDirs) {
        if (fs.statSync(entry).isDirectory()) {
            // Continue recursing this directory and remember the files there
            Array.prototype.push.apply(ret, enumFilesRecursiveSync(entry, predicate));
        } else {
            // remember this file
            ret.push(entry);
        }
    }
    return ret;
}

module.exports = {
    findIPs,
    rmdirRecursiveSync,
    getRepositoryFile,
    getFile,
    getJson,
    getInstalledInfo,
    sendDiagInfo,
    getAdapterDir,
    getDefaultDataDir,
    getConfigFileName,
    isThisInsideNodeModules,
    mkdirRecursiveSync,
    enumFilesRecursiveSync
};
