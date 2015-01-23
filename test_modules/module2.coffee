

{ Clusterized } = require '../'

class Module2 extends Clusterized

  process: (callback) ->
    @log "I'm Module2"
    callback()
