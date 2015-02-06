

{ Clusterized } = require '../'

class Module1 extends Clusterized
  constructor: ->
    @on 'test.event', (msg) ->
      @log msg

  process: (callback) ->
    @log "I'm Module1"
    callback()

module.exports = Module1
