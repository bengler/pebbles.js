$ = require("jquery")
_ = require("underscore")

connector = require("./connector")

service = exports

service.state = connector: null

service.connect = (host) ->  
  if window? && host? && host != window.location.host
    # We are running in a browser, off-site and need to initiate the cross domain stuff
    $.getScript "http://#{host}/api/connector/v1/assets/easyXDM.js", ->
      service.state.connector = new connector.XDMConnector(host)
      $(service).trigger("connected")
  else
    # Just basic ajax, thank you very much
    service.state.connector = new connector.BasicConnector()
    $(service).trigger("connected")


class service.ServiceSet
  constructor: (services) ->
    @use(services) if services?
  use: (services) ->
    _.each services, (version, name) =>
      @[name] = new service.GenericService
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