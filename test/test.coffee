$ = require('jquery')
_ = require('underscore')
lib = require('../index')
should = require('should')

describe 'Connector', ->
  it "can connect", ->
    should.not.exist(lib.state.connector)
    lib.connect()
    should.exist(lib.state.connector)
  
  it "will trigger a connect event", ->
    eventTriggered = false
    $(lib).bind "connected", ->
      eventTriggered = true      
    lib.connect()
    eventTriggered.should.be.true

describe 'ServiceSet', ->
  it "can describe a service and calculate certain values for it", ->
    set = new lib.ServiceSet({grove: 1})
    set.should.have.property('grove')
    set.grove.service_url("/post").should.equal("/api/grove/v1/post")

describe 'Uid', ->
  it "can parse one", -> 
    [klass, path, oid] = lib.Uid.parse("post:a.b.c$1")
    klass.should.equal('post')
    path.should.equal('a.b.c')
    oid.should.equal('1')

