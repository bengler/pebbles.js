$ = require("jquery")
_ = require("underscore")

connector = require("./connector")

service = exports

service.state = connector: null

supportedServices = {}

service.connect = (host) ->
  deferred = $.Deferred()
  if host? and host isnt window?.location.host and not $.support.cors
    # We are running off site in a browser that doesnt support CORS and need to fall back to easyXDM for crosstalk
    $.getScript "http://#{host}/easyxdm/easyXDM.js", ->
      service.state.connector = new connector.XDMConnector({host})
      deferred.resolve()
  else
    # Just basic ajax, thank you very much (note: jquery will gracefully turn to CORS if browser supports it)
    service.state.connector = new connector.BasicConnector({host})
    deferred.resolve()
  deferred.promise()

class service.ServiceSet
  constructor: (services) ->
    @use(services) if services?
  use: (services) ->
    _.each services, (version, name) =>
      constructor = supportedServices[name] || service.GenericService
      @[name] = new constructor {version, name}
        name: name
        version: version

class service.GenericService
  constructor: (options) ->
    @base_url = "/api/#{options.name}/v#{options.version}"
  service_url: (path) ->
    @base_url+path
  perform: (method, url, params) ->
    service.state.connector.perform(method, @service_url(url), params)
  get: (url, params) ->
    @perform('GET', url, params)
  cached_get: (url) ->
    service.state.connector.cached_get(@service_url(url))
  post: (url, params) ->
    @perform('POST', url, params)
  delete: (url, params) ->
    @perform('DELETE', url, params)

class service.CheckpointService extends service.GenericService

  login: (provider)->
    done = $.Deferred()
    win = window.open(@service_url("/login/#{provider}"), "checkpoint-login", 'width=600,height=400')
    poll = =>
      return done.reject() if win.closed

      @get("/identities/me").then (response)=>
        if (response.identity?.id == undefined)
          setTimeout(poll, 1000)
        else
          win.close()
          done.resolve(response)
    setTimeout(poll, 2000)
    done
  logout: ->
    @get("/logout")

supportedServices.checkpoint = service.CheckpointService


