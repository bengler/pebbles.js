_ = require("underscore")

trim = String::trim && (str)-> str.trim() || (str) -> str.replace(/^\s+|\s+$/g,'')

class Uid
  constructor: (klass, path, oid)->
    if arguments.length == 1 and typeof arguments[0] == 'string'
      return Uid.fromString(arguments[0])

    parse_klass = (value)->
      return null if !value
      throw new InvalidUidError("Invalid klass '#{value}'") unless Uid.valid_klass(value)
      value

    parse_path = (value)->
      return null if !value
      throw new InvalidUidError("Invalid path '#{value}'") unless Uid.valid_path(value)
      trim(value) || null

    extract_realm = (path)->
      path.split(".")[0] if path

    parse_oid = (value)->
      return null if !value
      throw new InvalidUidError("Invalid oid '#{value}'") unless Uid.valid_oid(value)
      trim(value) || null

    @klass = parse_klass(klass)
    @path = parse_path(path)
    @oid = parse_oid(oid)
    @realm = extract_realm(path)

    throw new InvalidUidError("Missing klass in uid") unless @klass
    throw new InvalidUidError("A valid uid must specify either path or oid") unless @path || @oid

  clone: ()->
    new Uid(@klass, @path, @oid)

  toString: ()->
    "#{@klass}:#{@path || ''}#{('$'+@oid if @oid) || ''}"

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
    uid = new Uid(string)
    [uid.klass, uid.path, uid.oid]

  valid_label: (value)->
    value.match /^[a-zA-Z0-9_-]+$/

  valid_klass: (value)->
    return false if value.match /^\./
    return false if value == ""
    for label in value.split('.')
      return false unless Uid.valid_label(label)
    true
    
  valid_path: (value)->
    return true if value == ''
    for label in value.split('.')
      return false unless Uid.valid_label(label)
    true

  valid_oid:(value)->
    value != null && value.indexOf('/') == -1

class Uid.InvalidUidError extends Error
  name: 'Uid.InvalidUidError'
  constructor: (@message)->

exports.Uid = Uid