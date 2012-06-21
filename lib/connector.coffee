connector = exports
path = require("path")

# Represents a connection to a pebbles endpoint.
class connector.AbstractConnector
  constructor: ({@host})->
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

  isXDomain: ->
    @host and @host isnt window?.location.host
    
# Your garden variety ajax driven connection
class connector.BasicConnector extends connector.AbstractConnector
  perform: (method, url, params, headers) ->
    
    url = "http://#{path.join(@host, url)}" if @host
    [method, url, params, headers] = @method_override(method, url, params, headers)

    deferred = $.Deferred()
    requestOpts =
      data: params
      type: method  
      headers: headers
      success: (response) ->
        deferred.resolve(try JSON.parse(response) catch e then response)
      error: (error) ->
        deferred.reject(error)

    #console.log("XDomain #{@isXDomain()}")
    requestOpts.xhrFields ||= {}
    requestOpts.xhrFields.withCredentials = true if @isXDomain()

    $.ajax url, requestOpts

    deferred.promise()

# An EasyXDM-based connection for cross domain situations where CORS isnt supported by browser
class connector.XDMConnector extends connector.AbstractConnector
  constructor: ->
    super
    @_xhr = new easyXDM.Rpc remote: "http://#{@host}/easyxdm/cors/index.html",
      remote:
        request: {} # request is exposed by /cors/

  perform: (method, url, params, headers) ->
    [method, url, params, headers] = @method_override(method, url, params, headers)

    deferred = $.Deferred()

    success = (response) ->
      deferred.resolve(try JSON.parse(response.data) catch e then response)

    error = (error) ->
      deferred.reject(error)

    @_xhr.request {url, method, headers, data: params}, success, error
    deferred.promise()