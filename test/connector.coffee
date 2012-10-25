should = require("should")
connector = require("../").connector
location = require("location")
sinon = require("sinon")
$ = require("jquery")

describe 'Connector', ->

  before ->
    global.window = location: require('location')

  after ->
    delete global.window

  it "creates a BasicConnector when host is not specified", ->
    connection = connector.connect()
    connection.should.be.an.instanceof(connector.BasicConnector)

  it "creates a BasicConnector if host is specified but equal to window.location.host ", ->
    connection = connector.connect("localhost:3000")
    connection.should.be.an.instanceof(connector.BasicConnector)

  it "creates an XDMConnector if host is different from the window.location.host and cors isnt supported", ->
    sinon.stub(connector, "XDMConnector")
    connection = connector.connect("foo.com")
    connector.XDMConnector.calledWithNew().should.equal true
    connection.should.be.an.instanceof(connector.XDMConnector)
    connector.XDMConnector.restore()

  it "creates a BasicConnector if host is different from window.location.host and cors is supported", ->
    $.support.cors = true
    connection = connector.connect("foo.com")
    connection.should.be.an.instanceof(connector.BasicConnector)
    $.support.cors = false
