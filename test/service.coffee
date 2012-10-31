should = require('should')
sinon = require('sinon')
$ = require('jquery')

{ServiceSet, GenericService} = require('../').service

describe 'ServiceSet', ->
  before ->
    global.window = location: require('location')

  after ->
    delete global.window

  it "can be initialized with a set of services", ->
    services = (new ServiceSet).use(myservice: {version: 1}, otherservice: 2)
    services.myservice.should.be.an.instanceof(GenericService)
    services.otherservice.should.be.an.instanceof(GenericService)

  it "can be initialized with a host", ->
    services = new ServiceSet(host: "foobar.com").use(anyservice: 1)
    services.anyservice.host.should.equal("foobar.com")

  it "can be configured with a host per service", ->
    services = new ServiceSet(host: "foobar.com").use(anyservice: {version: 1, host: "baz.com"})
    services.anyservice.host.should.equal("baz.com")
    services.anyservice.serviceUrl("/qux").should.equal("//baz.com/api/anyservice/v1/qux")

describe 'GenericService', ->
  it "can be initialized with host, name and version", ->
    service = new GenericService(host: 'foobar.com', name: "fooservice", version: 1)
    service.host.should.equal 'foobar.com'
    service.name.should.equal 'fooservice'
    service.version.should.equal 1

  it "builds a serviceUrl for a service endpoint", ->
    service = new GenericService({name: "foo", version: 1})
    service.serviceUrl("/bar").should.equal("/api/foo/v1/bar")

  it "builds a serviceUrl for a service endpoint", ->
    service = new GenericService({name: "foo", version: 1})
    service.serviceUrl("/bar").should.equal("/api/foo/v1/bar")

  describe "Its HTTP API", ->
    service = null
    beforeEach ->
      service = new GenericService({name: "foo", version: 1})

    it "provides a method for GET'ing a service resource", ->
      sinon.spy(service.connector, "perform")
      service.get("/bar/baz")
      service.connector.perform.calledWith("GET", "/api/foo/v1/bar/baz").should.be.ok

    it "provides a method for POST'ing a service resource", ->
      sinon.spy(service.connector, "perform")
      service.post("/bar/baz")
      service.connector.perform.calledWith("POST", "/api/foo/v1/bar/baz").should.be.ok

    it "provides a method for PUT'ing a service resource", ->
      sinon.spy(service.connector, "perform")
      service.put("/bar/baz")
      service.connector.perform.calledWith("PUT", "/api/foo/v1/bar/baz").should.be.ok

    it "provides a method for DELETE'ing a service resource", ->
      sinon.spy(service.connector, "perform")
      service.delete("/bar/baz")
      service.connector.perform.calledWith("DELETE", "/api/foo/v1/bar/baz").should.be.ok