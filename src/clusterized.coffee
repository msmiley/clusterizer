
timer = require 'metrics-timer'
uuid = require 'node-uuid'

{ EventEmitter } = require 'events'

#
# Base class for all clusterized modules. Provides facilities
# for modules to log, throw errors, time their execution, etc.
#
class Clusterized extends EventEmitter

  #
  # Module needs to override this function as an entry point to processing.
  #
  process: (callback) ->
    @log "module #{@name} needs to have a process(callback) function"

  #
  # Start the Module
  #
  start: ->
    @log "starting #{@name}"

    # set a default
    @moduleSleep = 1000 unless @moduleSleep

    @stopped = false

    # private function for one iteration, used to wrap setTimeout to allow asynchronicity
    # while ensuring there is a sleep period
    iterate = =>
      @log "sleeping for: #{@moduleSleep} ms"
      setTimeout =>
        if @stopped
          @log "stopped processing."
        else if @processing
          @log "skipping iteration because process() is already running"
        else
          uid = uuid.v1() # uid for this iteration
          @log "starting run: #{uid}"
          timer.start(uid)
          # call module with a callback for it to call on exit
          @processing = true
          @process (err) =>
            elapsed = timer.stop(uid)
            @processing = false
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
  # Perform one iteration when this function is called
  #
  kick: ->
    unless @processing
      uid = uuid.v1() # uid for this iteration
      @log "kicking module, run ##{uid}"
      timer.start(uid)
      # call module with a callback for it to call on exit
      @processing = true
      @process (err) =>
        elapsed = timer.stop(uid)
        @processing = false
        if err
          @error "error on kick ##{uid}: #{err} after #{elapsed}ms"
        else
          @log "completed kick ##{uid}, took: #{elapsed}ms"

  #
  # Send generic message to Master process
  #
  send: (event, msg) ->
    if event and msg
      process.send
        event: event
        message: msg

  #
  # Handle some messages, emit the rest for module to handle
  #
  recv: (msg) ->
    switch msg.event
      when 'clusterized.kick'
        @kick()
      when 'clusterized.stop'
        @stop()
      else # self-emit for user's code
        @emit msg.event, msg.message

  #
  # Provide a way for Clusterized module to get logging back to Master
  #
  log: (msg) ->
    @send 'log', msg


#
# Exports
#
module.exports = Clusterized
