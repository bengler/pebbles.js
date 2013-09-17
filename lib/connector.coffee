connector = exports
path = require("path")
$ = require("jquery")

##
# Low level transport details.
# Abstracts away differences between connections to same domain and cross domain
#

# Factory that returns a new connector to a given host
connector.connect = (host)->
  if host? and host isnt window?.location.host and not $.support.cors
    # We are running off site in a browser that doesnt support CORS and need to fall back to easyXDM for crosstalk
    new connector.XDMConnector({host})
  else
    # Just basic ajax, thank you very much (note: jquery will gracefully turn to CORS if browser supports it)
    new connector.BasicConnector({host})

# Represents a connection to a pebbles endpoint.
class connector.AbstractConnector
  constructor: ({@host})->
    @cache = {}

  cached_get: (url) ->
    console.log("AbstractConnector.cached_get is deprecated. Use cachedGet instead")
    @cachedGet(url)

  cachedGet: (url) ->
    @cache[url] ||= @perform('GET', url)
  # TODO: Expire keys when the cache grows big

  clearCache: ->
    @cache = {}

  # Pass parameters to .perform through this to
  # implement '_method' override hack
  methodOverride: (method, url, params, headers) ->
    headers ||= {}
    if method != 'GET' && method != 'POST'
      headers["X-Http-Method-Override"] = method
      params ||= {}
      params['_method'] = method
      method = 'POST'
    [method, url, params, headers]

  isXDomain: ->
    @host and @host isnt window?.location.host

# Your garden variety ajax driven connection
class connector.BasicConnector extends connector.AbstractConnector
  perform: (method, url, params, headers) ->
    [method, url, params, headers] = @methodOverride(method, url, params, headers)

    requestOpts =
      data: params
      type: method
      headers: headers

    if params and method == 'POST'
      requestOpts.contentType = 'application/json'
      requestOpts.data = if Object::toString.call(params) == '[object String]' then params else JSON.stringify(params)

    if @isXDomain()
      requestOpts.xhrFields ||= {}
      requestOpts.xhrFields.withCredentials = true

      # "jQuery by default doesn't set X-Requested-With for cross-domain requests, so you need to do this manually."
      #   - http://www.codeotaku.com/journal/2011-05/cross-domain-ajax/index
      requestOpts.headers["X-Requested-With"] = "XMLHttpRequest"

    $.ajax(url, requestOpts).then (response)->
      try JSON.parse(response) catch e then response

# An EasyXDM-based connection for cross domain situations where CORS isnt supported by browser
class connector.XDMConnector extends connector.AbstractConnector

  # Loads easyXDM.js from the server we are making connections to. Also ensures its only loaded once
  initEasyXDMFrom = do ->
    cache = {}
    (host)->

      # Ensure we load/initialize easyXDM at most once per host
      return cache[host] if cache[host]
      loaded = cache[host] = $.Deferred()

      basePath = "/api/checkpoint/v1/resources/easyXDM"

      easyXDMScriptUrl = "//#{host}#{basePath}/easyXDM.min.js"

      # Remember $.getScript will always succeed, even if the server returns 404
      $.getScript(easyXDMScriptUrl).then ->
        easyXDM = window.easyXDM? and window.easyXDM.noConflict('Pebbles')
        if easyXDM
          rpc = new easyXDM.Rpc(remote: "http://#{host}#{basePath}/cors/index.html", {remote: request: {}})
          loaded.resolve(rpc)
        else
          delete cache[host]
          loaded.reject("Could not load easyXDM from #{easyXDMScriptUrl}. Verify that the script is served from that location.")

  constructor: ->
    super
    @ready = initEasyXDMFrom(@host)
    @ready.fail (message)->
      throw new Error("Unable to initialize easyXDM: #{message}")

  perform: (method, url, params, headers) ->
    [method, url, params, headers] = @methodOverride(method, url, params, headers)

    deferred = $.Deferred()

    @ready.then (rpc)->
      if params and method == 'POST'
        headers['Content-Type'] = 'application/json'
        params = JSON.parse(params) if Object::toString.call(params) == '[object String]'

      success = (response) ->
        deferred.resolve(try JSON.parse(response.data) catch e then response)
  
      error = (error) ->
        deferred.reject(error)
        throw new Error("EasyXDM request error: #{error.message} (error code #{error.code}).")

      rpc.request {url, method, headers, data: params}, success, error
    deferred.promise()