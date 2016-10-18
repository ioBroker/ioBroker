var fs = require('fs');
var request;
var extend;

function rmdirRecursiveSync(path) {
    if (fs.existsSync(path)) {
        fs.readdirSync(path).forEach(function (file, index) {
            var curPath = path + '/' + file;
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
    var ifaces = require('os').networkInterfaces();
    var ipArr = [];
    for (var dev in ifaces) {
        /*jshint loopfunc:true */
        ifaces[dev].forEach(function (details) {
            if (!details.internal) ipArr.push(details.address);
        });
    }
    return ipArr;
}

function findPath(path, url, isImage) {
    if (!url) return '';
    if (url.substring(0, 'http://'.length)  === 'http://' ||
        url.substring(0, 'https://'.length) === 'https://') {
        return url;
    } else {
        if (path.substring(0, 'http://'.length)  === 'http://' ||
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
    if (urlOrPath.substring(0, 'http://'.length)  === 'http://' ||
        urlOrPath.substring(0, 'https://'.length) === 'https://') {
        var tmpFile = __dirname + '/../tmp/' + (fileName || Math.floor(Math.random() * 0xFFFFFFE) + '.zip');
        request(urlOrPath).on('error', function (error) {
            console.log('Cannot download  ' + tmpFile);
            if (callback) callback(tmpFile);
        }).pipe(fs.createWriteStream(tmpFile)).on('close', function () {
            console.log('downloaded ' + tmpFile);
            if (callback) callback(tmpFile);
        });
    } else {
        if (fs.existsSync(urlOrPath)) {
            if (callback) callback(urlOrPath);
        } else
        if (fs.existsSync(__dirname + '/../' + urlOrPath)) {
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
    var sources = {};
    // If object was read
    if (urlOrPath && typeof urlOrPath === 'object') {
        if (callback) callback(urlOrPath);
    } else
    if (!urlOrPath) {
        console.log('Empty url!');
        if (callback) callback(null);
    } else {
        if (urlOrPath.substring(0, 'http://'.length)  === 'http://' ||
            urlOrPath.substring(0, 'https://'.length) === 'https://') {
            request({url: urlOrPath, timeout: 5000}, function (error, response, body) {
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
                    sources = JSON.parse(fs.readFileSync(urlOrPath));
                } catch (e) {
                    console.log('Cannot parse json file from ' + urlOrPath + '. Error: ' + e);
                    if (callback) callback(null, urlOrPath);
                    return;
                }
                if (callback) callback(sources, urlOrPath);
            } else
            if (fs.existsSync(__dirname + '/../' + urlOrPath)) {
                try {
                    sources = JSON.parse(fs.readFileSync(__dirname + '/../' + urlOrPath));
                }catch (e) {
                    console.log('Cannot parse json file from ' + __dirname + '/../' + urlOrPath + '. Error: ' + e);
                    if (callback) callback(null, urlOrPath);
                    return;
                }
                if (callback) callback(sources, urlOrPath);
            } else if (fs.existsSync(__dirname + '/../tmp/' + urlOrPath)) {
                try {
                    sources = JSON.parse(fs.readFileSync(__dirname + '/../tmp/' + urlOrPath));
                } catch (e) {
                    console.log('Cannot parse json file from ' + __dirname + '/../tmp/' + urlOrPath + '. Error: ' + e);
                    if (callback) callback(null, urlOrPath);
                    return;
                }
                if (callback) callback(sources, urlOrPath);
            } else if (fs.existsSync(__dirname + '/../adapter/' + urlOrPath)) {
                try {
                    sources = JSON.parse(fs.readFileSync(__dirname + '/../adapter/' + urlOrPath));
                }catch (e) {
                    console.log('Cannot parse json file from ' + __dirname + '/../adapter/' + urlOrPath + '. Error: ' + e);
                    if (callback) callback(null, urlOrPath);
                    return;
                }
                if (callback) callback(sources, urlOrPath);
            } else {
                //if (urlOrPath.indexOf('/example/') === -1) console.log('Json file not found: ' + urlOrPath);
                if (callback) callback(null, urlOrPath);
                return;
            }
        }
    }
}

// Get list of all installed adapters and controller version on this host
function getInstalledInfo(hostRunningVersion) {
    var result = {};
    var path = __dirname + '/../';
    // Get info about host
    var ioPackage = JSON.parse(fs.readFileSync(path + 'io-package.json'));
    var package   = fs.existsSync(path + 'package.json') ? JSON.parse(fs.readFileSync(path + 'package.json')) : {};
    result[ioPackage.common.name] = {
        controller:     true,
        version:        ioPackage.common.version,
        icon:           ioPackage.common.extIcon || ioPackage.common.icon,
        title:          ioPackage.common.title,
        desc:           ioPackage.common.desc,
        platform:       ioPackage.common.platform,
        keywords:       ioPackage.common.keywords,
        readme:         ioPackage.common.readme,
        runningVersion: hostRunningVersion,
        license:        ioPackage.common.license ? ioPackage.common.license : ((package.licenses && package.licenses.length) ? package.licenses[0].type : ''),
        licenseUrl:     (package.licenses && package.licenses.length) ? package.licenses[0].url : ''
    };
    var dirs = fs.readdirSync(__dirname + '/../adapter');
    for (var i = 0; i < dirs.length; i++) {
        try {
            path = __dirname + '/../adapter/' + dirs[i] + '/';
            if (fs.existsSync(path + 'io-package.json')) {
                ioPackage = JSON.parse(fs.readFileSync(path + 'io-package.json'));
                package   = fs.existsSync(path + 'package.json') ? JSON.parse(fs.readFileSync(path + 'package.json')) : {};
                result[ioPackage.common.name] = {
                    controller: false,
                    version:    ioPackage.common.version,
                    icon:       ioPackage.common.extIcon || (ioPackage.common.icon ? '/adapter/' + dirs[i] + '/' + ioPackage.common.icon : ''),
                    title:      ioPackage.common.title,
                    desc:       ioPackage.common.desc,
                    platform:   ioPackage.common.platform,
                    keywords:   ioPackage.common.keywords,
                    readme:     ioPackage.common.readme,
                    type:       ioPackage.common.type,
                    license:    ioPackage.common.license ? ioPackage.common.license : ((package.licenses && package.licenses.length) ? package.licenses[0].type : ''),
                    licenseUrl: (package.licenses && package.licenses.length) ? package.licenses[0].url : ''
                };
            }
        } catch (e) {
            console.log('Cannot read or parse ' + __dirname + '/../adapter/' + dirs[i] + '/io-package.json: ' + e.toString());
        }
    }
    dirs = fs.readdirSync(__dirname + '/../node_modules');
    for (i = 0; i < dirs.length; i++) {
        try {
            path = __dirname + '/../node_modules/' + dirs[i] + '/';
            if (dirs[i].match(/^iobroker\./i) && fs.existsSync(path + 'io-package.json')) {
                ioPackage = JSON.parse(fs.readFileSync(path + 'io-package.json'));
                package   = fs.existsSync(path + 'package.json') ? JSON.parse(fs.readFileSync(path + 'package.json')) : {};
                result[ioPackage.common.name] = {
                    controller: false,
                    version:    ioPackage.common.version,
                    icon:       ioPackage.common.extIcon || (ioPackage.common.icon ? '/adapter/' + dirs[i] + '/' + ioPackage.common.icon : ''),
                    title:      ioPackage.common.title,
                    desc:       ioPackage.common.desc,
                    platform:   ioPackage.common.platform,
                    keywords:   ioPackage.common.keywords,
                    readme:     ioPackage.common.readme,
                    type:       ioPackage.common.type,
                    license:    ioPackage.common.license ? ioPackage.common.license : ((package.licenses && package.licenses.length) ? package.licenses[0].type : ''),
                    licenseUrl: (package.licenses && package.licenses.length) ? package.licenses[0].url : ''
                };
            }
        } catch (e) {
            console.log('Cannot read or parse ' + __dirname + '/../node_modules/' + dirs[i] + '/io-package.json: ' + e.toString());
        }
    }
    if (fs.existsSync(__dirname + '/../../../node_modules/iobroker.js-controller') ||
        fs.existsSync(__dirname + '/../../../node_modules/ioBroker.js-controller')) {
        dirs = fs.readdirSync(__dirname + '/../..');
        for (i = 0; i < dirs.length; i++) {
            try {
                path = __dirname + '/../../' + dirs[i] + '/';
                if (dirs[i].match(/^iobroker\./i) && dirs[i].substring('iobroker.'.length) !== 'js-controller' &&
                    fs.existsSync(path + 'io-package.json')) {
                    ioPackage = JSON.parse(fs.readFileSync(path + 'io-package.json'));
                    package   = fs.existsSync(path + 'package.json') ? JSON.parse(fs.readFileSync(path + 'package.json')) : {};
                    result[ioPackage.common.name] = {
                        controller: false,
                        version:    ioPackage.common.version,
                        icon:       ioPackage.common.extIcon || (ioPackage.common.icon ? '/adapter/' + dirs[i] + '/' + ioPackage.common.icon : ''),
                        title:      ioPackage.common.title,
                        desc:       ioPackage.common.desc,
                        platform:   ioPackage.common.platform,
                        keywords:   ioPackage.common.keywords,
                        readme:     ioPackage.common.readme,
                        license:    ioPackage.common.license ? ioPackage.common.license : ((package.licenses && package.licenses.length) ? package.licenses[0].type : ''),
                        licenseUrl: (package.licenses && package.licenses.length) ? package.licenses[0].url : ''
                    };
                }
            } catch (e) {
                console.log('Cannot read or parse ' + __dirname + '/../node_modules/' + dirs[i] + '/io-package.json: ' + e.toString());
            }
        }
    }
    return result;
}

function initNpm(prefix, callback) {
    if (typeof prefix === 'function') {
        callback = prefix;
        prefix = undefined;
    }

    var settings = {
        silent: true,
        global: false,
        production: true,
        minTimeout: 500,
        maxTimeout: 1500,
        times: 1
    };
    if (prefix) settings.prefix = prefix;

    var npm = require('npm');
    npm.load(settings, function (er) {
        // Disable debug outputs
        npm.registry.log.silly   = function () {};
        npm.registry.log.verbose = function () {};
        npm.registry.log.info    = function () {};
        npm.registry.log.http    = function () {};
        if (callback) callback(er, npm);
    });
}

// reads version of packet from npm
function getNpmVersion(adapter, callback) {
    adapter = adapter ? 'iobroker.' + adapter : 'iobroker';
    var config = require(getConfigFileName());

    if (0 && config.network.useSystemNpm) {
        var cmd = 'npm view ' + adapter + ' dist-tags.latest';
        //console.log(cmd + ' (System call)');
        // Install node modules as system call

        // System call used for update of js-controller itself,
        // because during installation npm packet will be deleted too, but some files must be loaded even during the install process.
        var exec = require('child_process').exec;
        var child = exec(cmd, function (error, stdout, stderr) {
            if (stdout) {
                var lines = stdout.split('\n');
                stdout = lines[0].replace('\r', '').trim();
            }
            if (callback) callback(error, stdout);
        });
    } else {
        try {
            initNpm(function (er, npm) {
                npm.commands.view([adapter, 'dist-tags.latest'], true, function (error, response) {
                    if (error) return callback ? callback(error) : 0;

                    if (response) {
                        if (callback) callback(error, Object.keys(response)[0]);
                    } else {
                        if (callback) callback(error);
                    }
                });
            });
        } catch (e) {
            console.log('error by reading ' + adapter + ': ' + e);
            if (callback) callback(e);
        }
    }
}

function getIoPack(sources, name, callback) {
    getJson(sources[name].meta, function (ioPack) {
        var packUrl = sources[name].meta.replace('io-package.json', 'package.json');
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

                if (sources[name].meta.substring(0, 'http://'.length)  === 'http://' ||
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
    var sources = {};
    var path =    '';
    var toRead =  0;
    var timeout = null;
    var count =   0;

    if (!extend) extend = require('node.extend');

    if (urlOrPath) {
        var parts = urlOrPath.split('/');
        path  = parts.splice(0, parts.length - 1).join('/') + '/';
    }

    // If object was read
    if (urlOrPath && typeof urlOrPath === 'object') {
        if (callback) callback(urlOrPath);
    } else
    if (!urlOrPath) {
        try {
            sources = JSON.parse(fs.readFileSync(__dirname + '/../conf/sources.json'));
        } catch (e) {
            sources = {};
        }
        try {
            var sourcesDist = JSON.parse(fs.readFileSync(__dirname + '/../conf/sources-dist.json'));
            sources = extend(true, sourcesDist, sources);
        } catch (e) {

        }

        for (var name in sources) {
            if (sources[name].url)  sources[name].url  = findPath(path, sources[name].url);
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
                for (var name in sources) {
                    if (sources[name].url)  sources[name].url  = findPath(path, sources[name].url);
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
        url:    'http://download.iobroker.org/diag.php',
        method: 'POST',
        headers: {'content-type': 'application/x-www-form-urlencoded'},
        body:    "data=" + JSON.stringify(obj),
        timeout: 2000
    }, function (err, response, body) {
        /*if (err || !body || response.statusCode !== 200) {

        }*/
    }).on('error', function (error) {
        console.log("Cannot send diag info: " + error.message);
    });
}

function getAdapterDir(adapter, isNpm) {
    var parts = __dirname.replace(/\\/g, '/').split('/');
    parts.splice(parts.length - 3, 3);
    var dir = parts.join('/');
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
    var dataDir = __dirname.replace(/\\/g, '/');
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
    var configDir = __dirname.replace(/\\/g, '/');
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

module.exports.findIPs =               findIPs;
module.exports.rmdirRecursiveSync =    rmdirRecursiveSync;
module.exports.getRepositoryFile =     getRepositoryFile;
module.exports.getFile =               getFile;
module.exports.getJson =               getJson;
module.exports.getInstalledInfo =      getInstalledInfo;
module.exports.sendDiagInfo =          sendDiagInfo;
module.exports.getAdapterDir =         getAdapterDir;
module.exports.getDefaultDataDir =     getDefaultDataDir;
module.exports.getConfigFileName =     getConfigFileName;
module.exports.initNpm =               initNpm;
