$ = require('jquery')
_ = require('underscore')
should = require('should')

service = require('..').service

describe 'Connector', ->
  it "can connect", ->
    should.not.exist(service.state.connector)
    service.connect()
    should.exist(service.state.connector)

  it "will trigger a connect event", ->
    eventTriggered = false
    $(service).bind "connected", ->
      eventTriggered = true
    service.connect()
    eventTriggered.should.be.true

describe 'ServiceSet', ->
  it "can describe a service and calculate certain values for it", ->
    set = new service.ServiceSet({grove: 1})
    set.should.have.property('grove')
    set.grove.service_url("/post").should.equal("/api/grove/v1/post")
