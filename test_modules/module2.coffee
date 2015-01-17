

{ Clusterized } = require '../'

class Module2 extends Clusterized

  process2: (callback) ->
    console.log "I'm Module2"
    callback()
