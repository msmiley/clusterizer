

{ Clusterized } = require '../'

class Module1 extends Clusterized

  process: (callback) ->
    @log "I'm Module1"
    callback()
