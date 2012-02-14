$ = require('jquery')
_ = require('underscore')
lib = require('../pebblecore')

describe 'Uid', ->
  it "can parse one", -> 
    [klass, path, oid] = lib.Uid.parse("post:a.b.c$1")
    klass.should.equal('post')
    path.should.equal('a.b.c')
    oid.should.equal('1')
