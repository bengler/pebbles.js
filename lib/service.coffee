$ = require("jquery")

connector = require("./connector")

service = exports

supportedServices = {}

class service.ServiceSet
  constructor: ({host}={})->
    # Don't keep host if its the same as the domain the page is on
    @host = host if host isnt window?.location.host

  use: (services) ->
    for name, opts of services
      unless isNaN(Number(opts))
        opts = version: opts
      Constructor = supportedServices[name] || service.GenericService

      throw Error('Missing required option "version"') unless opts.version

      @[name] = new Constructor(
        name: name
        host: if opts.hasOwnProperty('host') then opts.host else @host
        version: opts.version)
    this

class service.GenericService
  constructor: ({@host, @name, @version}) ->
    @connector = connector.connect(@host)

  basePath: ->
    "/api/#{@name}/v#{@version}"

  service_url: (path) ->
    console.log("GenericService.service_url is deprecated. Use serviceUrl instead")
    @serviceUrl(path)

  serviceUrl: (path) ->
    url = @basePath()+path
    url = "//#{@host}#{url}" if @host
    url

  perform: (method, endpoint, params) ->
    @connector.perform(method, @serviceUrl(endpoint), params)

  get: (endpoint, params) ->
    @perform('GET', endpoint, params)

  cachedGet: (endpoint) ->
    @connector.cachedGet(@serviceUrl(endpoint))

  post: (endpoint, params) ->
    @perform('POST', endpoint, params)

  delete: (endpoint, params) ->
    @perform('DELETE', endpoint, params)

  put: (url, params) ->
    @perform('PUT', url, params)


timed = (ms, f)->
  dfd = $.Deferred()
  setTimeout(dfd.resolve, ms)
  dfd.then(f)

class service.CheckpointService extends service.GenericService

  selectProvider: ->
    throw """Not implemented.
              Please implement this method in your app and make sure it returns a promise which
              resolves with the selected service"""

  login: (provider, opts={})->
    unless provider?
      return @selectProvider().then (provider)=>
        @login(provider, opts)

    url = @serviceUrl("/login/#{provider}")
    url += "?redirect_to=#{opts.redirectTo}" if opts.redirectTo?

    # Note: IE doesn't allow non-alphanumeric characters in window name. Changed from "checkpoint-login" to "checkpointlogin"
    win = window.open(url, "checkpointlogin", 'width=600,height=400')
    
    poll = =>
      @get("/identities/me").then (me)->
        if me.identity?.id? and not me.identity.provisional
          win.close()
          return me
        if win.closed
          return $.Deferred().reject("Login window closed by user")

        timed(opts.pollInterval || 1000, poll)

    poll()

  logout: ->
    @post("/logout")

supportedServices.checkpoint = service.CheckpointService