
uuid = require 'node-uuid'
timer = require 'metrics-timer'

#
# Base class for all clusterized modules. Provides facilities
# for modules to log, throw errors, time their execution, etc.
#
class Clusterized
  constructor: ->
    # set process name to match the name given to clusterizer
    @name = process.env.name
    process.title = "#{@name}"

    # get the name of the module this process will run
    @moduleName = process.env.module
    @moduleCallback = process.env.callback
    @moduleMode = process.env.mode
    @moduleSleep = process.env.interval

    @reset()

    # start the module
    @start @module[@moduleCallback]


  reset: ->
    # state flag
    @stopped = true
    # load the module
    @module = @loadModule


  loadModule: (name) ->
    # try to load the module
    try
      return require name
    catch e
      console.error "Error loading Module: #{name}"

  #
  # Start the Module
  #
  start: (callback) ->
    @log "starting"

    @stopped = false

    # private function for one iteration, used to wrap setTimeout to allow asynchronicity
    # while ensuring there is a sleep period
    iterate = =>
      @log "sleeping for: #{@sleep} ms"
      setTimeout =>
        if @stopped
          @log "stopped processing."
        else
          uid = uuid.v1() # uid for this iteration
          @log "starting run: #{uid}"
          timer.start(uid)
          # call analysis module with a callback for it to call on exit
          callback (err) =>
            elapsed = timer.stop(uid)
            if err
              @error "error on run #{uid}: #{err} after #{elapsed}ms"
            else
              @log "completed run #{uid}, took: #{elapsed}ms"
            iterate()
      , @moduleSleep

    # kick off iteration loop
    iterate()

  #
  # Stop Module and exit the process
  #
  stop: ->
    @stopped = true
    process.exit()


#
# Exports
#
module.exports = Clusterized
