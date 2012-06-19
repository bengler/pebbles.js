connector = exports

# Represents a connection to a pebbles endpoint.
class connector.AbstractConnector
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
class connector.BasicConnector extends connector.AbstractConnector
  constructor: ->
    super
  perform: (method, url, params, headers) -> 
    [method, url, params, headers] = @method_override(method, url, params, headers)
    deferred = $.Deferred()
    $.ajax url,
      data: params
      type: method  
      headers: headers
      success: (response) ->
        try
          response = JSON.parse(response)
        catch error
        deferred.resolve(response)
      error: (error) -> 
        deferred.reject(error)

    deferred.promise()

# An EasyXDM-based connection for cross domain situations
class connector.XDMConnector extends connector.AbstractConnector
  constructor:(@host) ->
    super
    @_xhr = new easyXDM.Rpc remote: "http://#{@host}/api/connector/v1/assets/cors.html",
      remote:
        request: {} # request is exposed by /cors/

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