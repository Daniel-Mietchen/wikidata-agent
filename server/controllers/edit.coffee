CONFIG = require 'config'
breq = require 'bluereq'
_ = require '../lib/utils'
wdk = require 'wikidata-sdk'
errors_ = require '../lib/errors'
archives_ = require '../lib/archives'
createClaim = require '../lib/create_claim'
{ whitelistedProperties, editableProperties, builders, tests } = require '../lib/helpers'

module.exports =
  post: (req, res, next) ->
    { body } = req
    unless body?
      return errors_.e400 res, 'empty body'

    _.log body, 'body'
    { entity, property, value, ref } = body

    unless wdk.isWikidataEntityId entity
      return errors_.e400 res, 'bad entity id', entity

    unless wdk.isWikidataPropertyId property
      return errors_.e400 res, 'bad property id', property

    unless property in editableProperties
      return errors_.e400 res, 'property isnt whitelisted yet', property

    unless value?
      return errors_.e400 res, 'empty value', value

    type = whitelistedProperties[property]
    test = tests[type]
    builder = builders[type]

    unless test value
      return errors_.e400 res, 'invalid value', value

    if archives_.repeatingHistory entity, property, value
      return errors_.e400 res, 'this value has already been posted', body

    if ref? and not /^http/.test ref
      return errors_.e400 res, 'invalid reference url', body

    createClaim entity, property, builder(value), ref
    .then archives_.updateArchives.bind(null, entity, property, value)
    .then res.json.bind(res)
    .catch errors_.e500.bind(null, res)
