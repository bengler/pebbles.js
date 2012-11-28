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
    if method != 'GET' && method != 'POST'
      headers ||= {}
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

    deferred = $.Deferred()
    requestOpts =
      data: params
      type: method
      headers: headers
      success: (response) ->
        deferred.resolve(try JSON.parse(response) catch e then response)
      error: (error) ->
        deferred.reject(error)

    if params and method == 'POST'
      requestOpts.contentType = 'application/json'
      requestOpts.data = JSON.stringify(params)

    requestOpts.xhrFields ||= {}
    requestOpts.xhrFields.withCredentials = true if @isXDomain()

    $.ajax url, requestOpts

    deferred.promise()

# An EasyXDM-based connection for cross domain situations where CORS isnt supported by browser
class connector.XDMConnector extends connector.AbstractConnector

  # Loads easyXDM.js from the server we are making connections to. Also ensures its only loaded once
  initEasyXDMFrom = do ->
    cache = {}
    (host)->
      return cache[host] if cache[host]

      loaded = cache[host] = $.Deferred()

      easyXDMUrl = "//#{host}/easyxdm/easyXDM.js" # Todo: make easyxdm url configurable
      loadEasyXDM = $.getScript(easyXDMUrl)
      loadEasyXDM.then ->
        rpc = new window.easyXDM.Rpc remote: "http://#{host}/easyxdm/cors/index.html", {remote: request: {}}
        loaded.resolve(rpc)
      loadEasyXDM.fail =>
        throw new Error("Could not load easyXDM from #{easyXDMUrl}. Verify that it is hosted at that location.")
        delete @cache[host]
      loaded

  constructor: ->
    super
    @ready = initEasyXDMFrom(@host)

  perform: (method, url, params, headers) ->
    [method, url, params, headers] = @methodOverride(method, url, params, headers)

    deferred = $.Deferred()

    success = (response) ->
      deferred.resolve(try JSON.parse(response.data) catch e then response)

    error = (error) ->
      deferred.reject(error)
      throw new Error("EasyXDM request error: #{error.message} (error code #{error.code}).")

    @ready.then (rpc)->
      rpc.request {url, method, headers, data: params}, success, error
    deferred.promise()