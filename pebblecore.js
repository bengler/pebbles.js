

/* pebblecore.js.coffee */

(function() {
  var $, AbstractConnector, BasicConnector, InvalidUidError, Uid, XDMConnector, connected_deferred, pebblecore, _,
    __hasProp = Object.prototype.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

  _ = require('underscore');

  $ = require('jquery');

  pebblecore = {};

  AbstractConnector = (function() {

    function AbstractConnector() {
      this.cache = {};
    }

    AbstractConnector.prototype.cached_get = function(url) {
      var _base;
      return (_base = this.cache)[url] || (_base[url] = this.perform('GET', url));
    };

    AbstractConnector.prototype.clear_cache = function() {
      return this.cache = {};
    };

    AbstractConnector.prototype.method_override = function(method, url, params, headers) {
      if (method !== 'GET' && method !== 'POST') {
        headers || (headers = {});
        headers["X-Http-Method-Override"] = method;
        params || (params = {});
        params['_method'] = method;
        method = 'POST';
      }
      return [method, url, params, headers];
    };

    return AbstractConnector;

  })();

  BasicConnector = (function(_super) {

    __extends(BasicConnector, _super);

    function BasicConnector() {
      BasicConnector.__super__.constructor.apply(this, arguments);
    }

    BasicConnector.prototype.perform = function(method, url, params, headers) {
      var deferred, _ref;
      _ref = this.method_override(method, url, params, headers), method = _ref[0], url = _ref[1], params = _ref[2], headers = _ref[3];
      deferred = $.Deferred();
      $.ajax(url, {
        data: params,
        type: method,
        success: function(response) {
          try {
            return deferred.resolve(JSON.parse(response));
          } catch (error) {
            return deferred.resolve(response);
          }
        },
        error: function(error) {
          return deferred.reject(error);
        },
        headers: headers
      });
      return deferred.promise;
    };

    return BasicConnector;

  })(AbstractConnector);

  XDMConnector = (function(_super) {

    __extends(XDMConnector, _super);

    function XDMConnector(host) {
      this.host = host;
      XDMConnector.__super__.constructor.apply(this, arguments);
      this._xhr = new easyXDM.Rpc({
        remote: "http://" + this.host + "/api/connector/v1/assets/cors.html"
      }, {
        remote: {
          request: {}
        }
      });
    }

    XDMConnector.prototype.perform = function(method, url, params, headers) {
      var config, deferred, error, success, _ref;
      _ref = this.method_override(method, url, params, headers), method = _ref[0], url = _ref[1], params = _ref[2], headers = _ref[3];
      deferred = $.Deferred();
      success = function(response) {
        try {
          return deferred.resolve(JSON.parse(response.data));
        } catch (error) {
          return deferred.resolve(response.data);
        }
      };
      error = function(error) {
        return deferred.reject(error);
      };
      config = {
        url: url,
        data: params,
        method: method,
        headers: headers
      };
      this._xhr.request(config, success, error);
      return deferred.promise;
    };

    return XDMConnector;

  })(AbstractConnector);

  pebblecore.connector = null;

  connected_deferred = $.Deferred();

  pebblecore.connected = connected_deferred.promise;

  pebblecore.connect = function(host) {
    if ((host != null) && host !== window.location.host) {
      $.getScript("http://" + host + "/api/connector/v1/assets/easyXDM.js", function() {
        pebblecore.connector = new XDMConnector(host);
        if (connected_deferred != null) {
          return connected_deferred.resolve(pebblecore.connector);
        }
      });
    } else {
      pebblecore.connector = new BasicConnector();
      if (connected_deferred != null) {
        connected_deferred.resolve(pebblecore.connector);
      }
    }
    return connected_deferred = null;
  };

  pebblecore.ServiceSet = (function() {

    function ServiceSet(services) {
      if (services != null) this.use(services);
    }

    ServiceSet.prototype.use = function(services) {
      var _this = this;
      return _.each(services, function(version, name) {
        return _this[name] = new pebblecore.GenericService({
          name: name,
          version: version
        });
      });
    };

    return ServiceSet;

  })();

  pebblecore.GenericService = (function() {

    function GenericService(options) {
      this.base_url = "/api/" + options.name + "/v" + options.version;
    }

    GenericService.prototype.service_url = function(path) {
      return this.base_url + path;
    };

    GenericService.prototype.perform = function(method, url, params) {
      return pebblecore.connector.perform(method, this.service_url(url), params);
    };

    GenericService.prototype.get = function(url, params) {
      return this.perform('GET', url, params);
    };

    GenericService.prototype.cached_get = function(url) {
      return pebblecore.connector.cached_get(this.service_url(url));
    };

    GenericService.prototype.post = function(url, params) {
      return this.perform('POST', url, params);
    };

    GenericService.prototype["delete"] = function(url, params) {
      return this.perform('DELETE', url, params);
    };

    return GenericService;

  })();

  pebblecore.services = new pebblecore.ServiceSet;

  InvalidUidError = (function(_super) {

    __extends(InvalidUidError, _super);

    InvalidUidError.prototype.name = 'InvalidUidError';

    function InvalidUidError(message) {
      this.message = message;
    }

    return InvalidUidError;

  })(Error);

  Uid = (function() {

    function Uid(klass, path, oid) {
      var parse_klass, parse_oid, parse_path,
        _this = this;
      if (arguments.length === 1 && typeof arguments[0] === 'string') {
        return Uid.fromString(arguments[0]);
      }
      parse_klass = function(value) {
        if (!value) return null;
        if (!Uid.valid_klass(value)) {
          throw new InvalidUidError("Invalid klass '" + value + "'");
        }
        return value;
      };
      parse_path = function(value) {
        if (!value) return null;
        if (!Uid.valid_path(value)) {
          throw new InvalidUidError("Invalid path '" + value + "'");
        }
        return $.trim(value) || null;
      };
      parse_oid = function(value) {
        if (!value) return null;
        if (!Uid.valid_oid(value)) {
          throw new InvalidUidError("Invalid oid '" + value + "'");
        }
        return $.trim(value) || null;
      };
      this.klass = parse_klass(klass);
      this.path = parse_path(path);
      this.oid = parse_oid(oid);
      if (!this.klass) throw new InvalidUidError("Missing klass in uid");
      if (!(this.path || this.oid)) {
        throw new InvalidUidError("A valid uid must specify either path or oid");
      }
    }

    Uid.prototype.clone = function() {
      return new Uid(this.klass, this.path, this.oid);
    };

    Uid.prototype.toString = function() {
      return "" + this.klass + ":" + this.path + ((this.oid ? '$' + this.oid : void 0) || '');
    };

    return Uid;

  })();

  _.extend(Uid, {
    fromString: function(string) {
      var klass, oid, path, _ref;
      _ref = Uid.raw_parse(string), klass = _ref[0], path = _ref[1], oid = _ref[2];
      return new Uid(klass, path, oid);
    },
    raw_parse: function(string) {
      var klass, match, oid, path, re, _ref;
      re = /((.*)^[^:]+)?\:([^\$]*)?\$?(.*$)?/;
      if (!(match = string.match(re))) return [];
      return _ref = [match[1], match[3], match[4]], klass = _ref[0], path = _ref[1], oid = _ref[2], _ref;
    },
    valid: function(string) {
      try {
        if (new Uid(string)) return true;
      } catch (InvalidUidError) {
        return false;
      }
    },
    parse: function(string) {
      var uid;
      uid = new Uid(string);
      return [uid.klass, uid.path, uid.oid];
    },
    valid_label: function(value) {
      return value.match(/^[a-zA-Z0-9_]+$/);
    },
    valid_klass: function(value) {
      return Uid.valid_label(value);
    },
    valid_path: function(value) {
      _.each(value.split('.'), function(label) {
        if (!Uid.valid_label(label)) return false;
      });
      return true;
    },
    valid_oid: function(value) {
      return Uid.valid_label(value);
    }
  });

  pebblecore.Uid = Uid;

  if (typeof exports !== "undefined" && exports !== null) {
    _.extend(exports, pebblecore);
  } else {
    this.pebblecore = pebblecore;
  }

}).call(this);
