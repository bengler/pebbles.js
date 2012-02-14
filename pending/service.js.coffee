class Pebbles.ServiceSet
  constructor: (services) ->
    @use(services) if services?
  use: (services) ->
    Pebbles._.each services, (version, name) =>
      Client = Pebbles._service_clients[name] || Pebbles.GenericService
      @[name] = new Client
        name: name
        version: version

  # Gets you the template in question, possibly loading it from the kit. The
  # result is a promise, so you should do something like this:
  #
  #     services.template('vanilla.comments').then(...)
  #
  # To hint to the TemplateLibrarian that it should load all templates for a 
  # kit you could just call template with kit-name:
  #
  #     services.template('vanilla')  
 
  template: (name) ->
    [service, name] = name.split('.')
    unless @[service]?
      throw "#{service} must be in your service set if you want to use the template '#{name}'" 
    package_url = @[service].service_url('/parts/client_templates.json')    
    defered = Pebbles.when.defer()
    success = (package) -> defered.resolve(package[name])
    failure = (error) -> defered.reject(error)
    Pebbles.template_library.get_package(service, package_url).then(success, failure)
    defered.promise  

class Pebbles.GenericService
  constructor: (options) ->
    @base_url = "/api/#{options.name}/v#{options.version}"
  service_url: (path) -> 
    @base_url+path
  perform: (method, url, params) ->
    Pebbles.connector.perform(method, @service_url(url), params)
  get: (url, params) ->
    @perform('GET', url, params)
  cached_get: (url) ->
    Pebbles.connector.cached_get(@service_url(url))
  post: (url, params) ->
    @perform('POST', url, params)
  delete: (url, params) ->
    @perform('DELETE', url, params)

# If you generally want a specific class to be instantiated as a client for 
# a specific pebble, make an entry in this object: {pebble_name: YourClientClass}
# see checkpoint.js.coffee for an example
Pebbles._service_clients = {}

Pebbles.services = new Pebbles.ServiceSet
