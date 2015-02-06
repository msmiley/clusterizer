

{ Clusterized } = require '../'

class Module1 extends Clusterized
  constructor: ->
    @on 'echo', (msg) ->
      @send 'echo', msg

  process: (callback) ->
    @log "I'm Module1"
    callback()

module.exports = Module1
