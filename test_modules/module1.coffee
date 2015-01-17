

{ Clusterized } = require '../'

class Module1 extends Clusterized

  process1: (callback) ->
    console.log "I'm Module1"
    callback()
