_ = require('underscore')
$ = require('jquery')

console.log(exports)
pebblecore = exports if exports?
pebblecore ||= {}

pebblecore.VERSION = '0.0.0'

state = {connector: null}
pebblecore.state = state

# ---------------------------------------------------------
#  Connectors
# ---------------------------------------------------------

# Represents a connection to a pebbles endpoint.
class AbstractConnector
  constructor: ->
    @cache = {}
  cached_get: (url) ->
    @cache[url] ||= @perform('GET', url)
  # TODO: Expire keys when the cache grows big
  clear_cache: -> 
    @cache = {}
  # Pass parameters to .perform through this to
  # implement '_method' override hack
  method_override: (method, url, params, headers) ->    
    if method != 'GET' && method != 'POST'
      headers ||= {}
      headers["X-Http-Method-Override"] = method
      params ||= {}
      params['_method'] = method
      method = 'POST'
    [method, url, params, headers]

# Your garden variety ajax driven connection
class BasicConnector extends AbstractConnector
  constructor: ->
    super
  perform: (method, url, params, headers) -> 
    [method, url, params, headers] = @method_override(method, url, params, headers)
    deferred = $.Deferred()
    $.ajax url,
      data: params
      type: method
      success: (response) ->
        try
          deferred.resolve(JSON.parse(response))
        catch error
          deferred.resolve(response)
      error: (error) -> 
        deferred.reject(error)
      headers: headers
    deferred.promise()

# An EasyXDM-based connection for cross domain situations
class XDMConnector extends AbstractConnector
  constructor:(@host) ->
    super
    @_xhr = new easyXDM.Rpc({remote: "http://#{@host}/api/connector/v1/assets/cors.html"},
      remote: 
        request: {} # request is exposed by /cors/
    )  
  perform: (method, url, params, headers) ->
    [method, url, params, headers] = @method_override(method, url, params, headers)
    deferred = $.Deferred()
    success = (response) ->
      try
        deferred.resolve(JSON.parse(response.data))
      catch error
        deferred.resolve(response.data)
    error = (error) -> 
      deferred.reject(error)
    config = {url: url, data: params, method: method, headers: headers}
    @_xhr.request config, success, error
    deferred.promise()
  
pebblecore.connect = (host) ->  
  if window? && host? && host != window.location.host
    # We are running in a browser, off-site and need to initiate the cross domain stuff
    $.getScript "http://#{host}/api/connector/v1/assets/easyXDM.js", ->
      state.connector = new XDMConnector(host)
      $(pebblecore).trigger("connected")
  else
    # Just basic ajax, thank you very much
    state.connector = new BasicConnector()
    $(pebblecore).trigger("connected")

# ---------------------------------------------------------
#  Services
# ---------------------------------------------------------

class pebblecore.ServiceSet
  constructor: (services) ->
    @use(services) if services?
  use: (services) ->
    _.each services, (version, name) =>
      @[name] = new pebblecore.GenericService
        name: name
        version: version

class pebblecore.GenericService
  constructor: (options) ->
    @base_url = "/api/#{options.name}/v#{options.version}"
  service_url: (path) -> 
    @base_url+path
  perform: (method, url, params) ->
    state.connector.perform(method, @service_url(url), params)
  get: (url, params) ->
    @perform('GET', url, params)
  cached_get: (url) ->
    state.connector.cached_get(@service_url(url))
  post: (url, params) ->
    @perform('POST', url, params)
  delete: (url, params) ->
    @perform('DELETE', url, params)

# ---------------------------------------------------------
#  Uids
# ---------------------------------------------------------

class InvalidUidError extends Error
  name: 'InvalidUidError'
  constructor: (@message)->

class Uid
  constructor: (klass, path, oid)->
    if arguments.length == 1 and typeof arguments[0] == 'string'
      return Uid.fromString(arguments[0])

    parse_klass = (value)=>
      return null if !value
      throw new InvalidUidError("Invalid klass '#{value}'") unless Uid.valid_klass(value)
      value

    parse_path = (value)=>
      return null if !value
      throw new InvalidUidError("Invalid path '#{value}'") unless Uid.valid_path(value)
      $.trim(value) || null

    parse_oid = (value)=>
      return null if !value
      throw new InvalidUidError("Invalid oid '#{value}'") unless Uid.valid_oid(value)
      $.trim(value) || null

    @klass = parse_klass(klass)
    @path = parse_path(path)
    @oid = parse_oid(oid)

    throw new InvalidUidError("Missing klass in uid") unless @klass
    throw new InvalidUidError("A valid uid must specify either path or oid") unless @path || @oid

  clone: ()->
    new Uid(@klass, @path, @oid)

  toString: ()->
    "#{@klass}:#{@path}#{('$'+@oid if @oid) || ''}"

_.extend Uid,
  fromString: (string) ->
    [klass, path, oid] = Uid.raw_parse(string)
    new Uid(klass, path, oid)

  raw_parse: (string)->
    re = /((.*)^[^:]+)?\:([^\$]*)?\$?(.*$)?/
    return [] unless match = string.match(re)
    [klass, path, oid] = [match[1], match[3], match[4]]

  valid: (string)->
    try
      true if new Uid(string)
    catch InvalidUidError
      false

  parse: (string)->
    uid = new Uid(string)
    [uid.klass, uid.path, uid.oid]

  valid_label: (value)->
    value.match /^[a-zA-Z0-9_]+$/

  valid_klass: (value)->
    Uid.valid_label(value)

  valid_path:(value)->
    _.each value.split('.'), (label)->
      return false unless Uid.valid_label(label)
    true

  valid_oid:(value)->
    Uid.valid_label(value)

pebblecore.Uid = Uid

@pebblecore = pebblecore unless exports?
