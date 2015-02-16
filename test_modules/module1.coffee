

{ Clusterized } = require '../'

class Module1 extends Clusterized
  constructor: ->
    @on 'echo', (msg) ->
      @send 'echo', msg

  process: (callback) ->
    @log "I'm Module1"
    throw new Error("test error")
    callback()

module.exports = Module1
