$ = require("jquery")

connector = require("./connector")

{EventEmitter} = require("events")

service = exports

supportedServices = {}

passevent = (type, scope)->
  (data)=> scope.emit(type, data)

setCookie = (name, value, minutes)->
  expires = ""
  if minutes
    date = new Date()
    date.setTime(date.getTime()+(minutes*60*1000))
    expires = "; expires="+date.toGMTString()
  document.cookie = "#{name}=#{value}#{expires}; path=/"

class service.ServiceSet extends EventEmitter
  constructor: ({host}={})->
    # Don't keep host if its the same as the domain the page is on
    @host = host if host isnt window?.location.host
  
  use: (services) ->
    for name, opts of services
      unless isNaN(Number(opts))
        opts = version: opts
      Constructor = supportedServices[name] || service.GenericService
  
      throw Error('Missing required option "version"') unless opts.version
  
      s = new Constructor(
        name: name
        host: if opts.hasOwnProperty('host') then opts.host else @host
        version: opts.version)
  
      s.on 'request', passevent('request', @)
      s.on 'success', passevent('success', @)
      s.on 'fail', passevent('fail', @)
      s.on 'done', passevent('done', @)
      @[name] = s
    this

class service.GenericService extends EventEmitter
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
    request = @connector.perform(method, @serviceUrl(endpoint), params)
    data = {service: this, request}
    @emit('request', data)
    request.then => @emit('success', data)
    request.fail => @emit('fail', data)
    request.always => @emit('done', data)
    request
  
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

class service.CheckpointService extends service.GenericService

  selectProvider: ->
    throw """Not implemented.
          Please implement this method in your app and make sure it returns a promise which
          resolves with the selected service"""

  _registerFocusMessageHandler: ->
    @_registerFocusMessageHandler = Function::
    handleMessage = (e)-> window.focus() if (e.data == 'checkpoint-login-success')
    window.addEventListener("message", handleMessage, false)

  login: (provider, opts={})->

    opts.pollInterval ||= 1000
    opts.display ||= 'popup'

    unless provider?
      return @selectProvider().then (provider)=>
        @login(provider, opts)

    params = []
    params.push("display=#{opts.display}")
    params.push("redirect_to=#{opts.redirectTo}") if opts.redirectTo?
    url = @serviceUrl("/login/#{provider}?#{params.join("&")}")

    # Hack to avoid getting stuck in browsers which doesn't open new windows but rather navigates to urls passed to
    # window.open(), or ignores the target="_blank" attribute on <a tags. This applies to, for example, the in-app 
    # browser in Twitter for iOS.
    # Note: The following cookie should be read from the page located at the opts.redirectTo url, which then must be 
    # located at the current domain.
    # This hack should be considered a *last resort* workaround.
    setCookie("checkpoint_login_source_url", document.location.href)

    # Note: IE doesn't allow non-alphanumeric characters in window name. Changed from "checkpoint-login" to "checkpointlogin"
    win = window.open(url, "checkpointlogin_"+new Date().getTime(), 'width=1024,height=800')
    #window.location.href = url    return
    @_registerFocusMessageHandler()
    deferred = $.Deferred()
    poll = =>
      @get("/identities/me").then (me)->
        if me.identity?.id? and not me.identity.provisional
          win.close()
          window.focus()
          deferred.resolve(me)
          clearInterval(pollId)
        if win.closed
          deferred.reject("Login window closed by user")

    pollId = setInterval poll, opts.pollInterval
    deferred

  logout: ->
    @post("/logout")

supportedServices.checkpoint = service.CheckpointService