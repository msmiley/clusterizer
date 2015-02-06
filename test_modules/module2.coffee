

{ Clusterized } = require '../'

class Module2 extends Clusterized
  constructor: ->
    @on 'echo', (msg) ->
      @send 'echo', msg

  process: (callback) ->
    @log "I'm Module2"
    callback()

module.exports = Module2
