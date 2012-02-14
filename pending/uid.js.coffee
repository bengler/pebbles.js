# Requires jQuery + underscore

$ = Pebbles.$
_ = Pebbles._

class InvalidUidError extends Error
  name: 'InvalidUidError'
  constructor: (@message)->

class Uid
  constructor: (klass, path, oid)->
    if arguments.length == 1 and typeof arguments[0] == 'string'
      return Uid.fromString(arguments[0])

    parse_klass = (value)=>
      return null if !value
      throw new InvalidUidError("Invalid klass '#{value}'") unless Uid.valid_klass(value)
      value

    parse_path = (value)=>
      return null if !value
      throw new InvalidUidError("Invalid path '#{value}'") unless Uid.valid_path(value)
      $.trim(value) || null

    parse_oid = (value)=>
      return null if !value
      throw new InvalidUidError("Invalid oid '#{value}'") unless Uid.valid_oid(value)
      $.trim(value) || null

    @klass = parse_klass(klass)
    @path = parse_path(path)
    @oid = parse_oid(oid)

    throw new InvalidUidError("Missing klass in uid") unless @klass
    throw new InvalidUidError("A valid uid must specify either path or oid") unless @path || @oid

  clone: ()->
    new Uid(@klass, @path, @oid)

  toString: ()->
    "#{@klass}:#{@path}#{('$'+@oid if @oid) || ''}"

_.extend Uid,
  fromString: (string) ->
    [klass, path, oid] = Uid.raw_parse(string)
    new Uid(klass, path, oid)

  raw_parse: (string)->
    re = /((.*)^[^:]+)?\:([^\$]*)?\$?(.*$)?/
    return [] unless match = string.match(re)
    [klass, path, oid] = [match[1], match[3], match[4]]

  valid: (string)->
    try
      true if new Uid(string)
    catch InvalidUidError
      false

  parse: (string)->
    uid = new Parser(string)
    [uid.klass, uid.path, uid.oid]

  valid_label: (value)->
    value.match /^[a-zA-Z0-9_]+$/

  valid_klass: (value)->
    Uid.valid_label(value)

  valid_path:(value)->
    _.each value.split('.'), (label)->
      return false unless Uid.valid_label(label)
    true

  valid_oid:(value)->
    Uid.valid_label(value)

Pebbles.Uid = Uid