should = require "should"

{Uid, InvalidUidError} = require("..").uid

describe 'Uid', ->
  it "can parse one", ->
    [klass, path, oid] = Uid.parse("post:a.b.c$1")
    klass.should.equal('post')
    path.should.equal('a.b.c')
    oid.should.equal('1')

  it "parses a full uid correctly", ->
    uid = Uid.fromString "klass:path$oid"
    uid.klass.should.eql "klass"
    uid.path.should.eql "path"
    uid.oid.should.eql "oid"
    uid.toString().should.eql "klass:path$oid"

  it "parses an uid with no oid correctly", ->
    uid = Uid.fromString "klass:path"
    uid.klass.should.eql "klass"
    uid.path.should.eql "path"
    should.not.exist uid.oid
    uid.toString().should.eql "klass:path"

  it "parses an uid with no path correctly", ->
    uid = Uid.fromString "klass:$oid"
    uid.klass.should.eql "klass"
    should.not.exist uid.path
    uid.oid.should.eql "oid"
    uid.toString().should.eql "klass:$oid"

  it "can be created with a string", ->
    uid = new Uid "klass:some.path$oid"
    uid.toString().should.eql "klass:some.path$oid"

  it "can be created using parameters", ->
    uid = new Uid 'klass', 'some.path', 'oid'
    uid.toString().should.eql "klass:some.path$oid"

  it "raises an error if parameter is neither string or hash", ->
    (-> Uid.fromString []).should.throw()
    (-> Uid.fromString NaN).should.throw()
    (-> Uid.fromString Number()).should.throw()

  it "raises an exception when you try to create an invalid uid", ->
    (-> new Uid '!', 'some.path', 'oid').should.throw InvalidUidError

  describe 'Parent', ->

    it "has a parent", ->
      uid = new Uid "klass:some.old.path$oid"
      uid.parent().should.eql "klass:some.old$path"

    it "has a parent even without an oid", ->
      uid = new Uid "klass:some.old.path"
      uid.parent().should.eql "klass:some.old$path"

    it "has a parent even with only one label", ->
      uid = new Uid "klass:some"
      uid.parent().should.eql "klass:$some"

    it "has a parent with a different klass", ->
      uid = new Uid "klass:some.old.path$oid"
      uid.parent('otherklass').should.eql "otherklass:some.old$path"

  describe 'Children', ->

    it "has children", ->
      uid = new Uid "klass:some.old.path$oid"
      uid.children().should.eql "*:some.old.path.oid"

    it "has children with a different klass", ->
      uid = new Uid "klass:some.old.path$oid"
      uid.children('otherklass').should.eql "otherklass:some.old.path.oid"

  describe 'ChildPath', ->

    it "has a childPath", ->
      uid = new Uid "klass:some.old.path$oid"
      uid.childPath().should.eql "some.old.path.oid"


  describe "klass", ->
    path_oid = "path$oid"

    it "allows sub-klasses", ->
      (-> Uid.fromString "sub.sub.class:#{path_oid}" ).should.not.throw()

      describe "is valid", ->
        (c for c in '.-_8').forEach (nice_character) ->
          it "with '#{nice_character}'", ->
            (-> Uid.fromString "a#{nice_character}b:#{path_oid}" ).should.not.throw()

      describe "is invalid", ->
        (c for c in '!/:$%').forEach (funky_character) ->
          it "with '#{funky_character}'", ->
            (-> Uid.fromString "a#{funky_character}b:#{path_oid}" ).should.throw InvalidUidError
  
  describe "oid", ->
    [
      "abc123",
      "abc123!@\#$%^&*()[]{}",
      "abc 123",
      "alice@example.com",
      "abc/123",
      "post:some.path$oid",
    ].forEach (oid) ->
      it "'#{oid}' is a valid oid if escaped", ->
        Uid.valid_oid(encodeURIComponent(oid)).should.be.true

    it "'abc/123' is an invalid oid", ->
      Uid.valid_oid('abc/123').should.be.false

    it "can be missing", ->
      should.not.exist Uid.fromString('klass:path').oid

    it "is not valid if it is null", ->
      Uid.valid_oid(null).should.be.false

  it "rejects invalid labels for klass", ->
    Uid.valid_klass("abc123").should.be.true
    Uid.valid_klass("abc123!").should.be.false
    Uid.valid_klass("").should.be.false

  describe "path", ->
    it "accepts valid paths", ->
      Uid.valid_path("").should.be.true
      Uid.valid_path("abc123").should.be.true
      Uid.valid_path("abc.123").should.be.true
      Uid.valid_path("abc.de-f.123").should.be.true

    it "rejects invalid paths", ->
      Uid.valid_path("abc!.").should.be.false
      Uid.valid_path(".").should.be.false
      Uid.valid_path("ab. 123").should.be.false

  it "knows how to parse in place", ->
    Uid.parse("klass:path$oid").should.eql ['klass', 'path', 'oid']
    Uid.parse("post:this.is.a.path.to$object_id").should.eql ['post', 'this.is.a.path.to', 'object_id']
    Uid.parse("post:$object_id").should.eql ['post', null, 'object_id']

  it "knows the valid uids from the invalid ones", ->
    Uid.valid("F**ing H%$#!!!").should.be.false
    Uid.valid("").should.be.false
    Uid.valid("bang:").should.be.false
    Uid.valid(":bang").should.be.false
    Uid.valid(":bang$paff").should.be.false
    Uid.valid("$paff").should.be.false
    Uid.valid("a:b.c.d$e").should.be.true
    Uid.valid("a:$e").should.be.true
    Uid.valid("a:b.c.d").should.be.true

  it "knows how to extract the realm from the path", ->
    Uid.fromString("klass:realm.other.stuff$3").realm.should.eql 'realm'
    Uid.fromString("klass:realm$3").realm.should.eql 'realm'
    Uid.fromString("klass:realm").realm.should.eql 'realm'
    should.not.exist Uid.fromString("klass:$3").realm

  describe "equality", ->
    uid = "klass:realm$3"
    it "is dependent on the actual uid", ->
      Uid.fromString("klass:realm$3").should.eql new Uid("klass:realm$3")

    it "also works for ==", ->
      Uid.fromString("klass:realm$3").should.eql new Uid("klass:realm$3")
