
timer = require 'metrics-timer'
uuid = require 'node-uuid'
Agenda = require 'agenda'
humanInterval = require 'human-interval'

{ EventEmitter } = require 'events'

#
# Base class for all clusterized modules. Provides facilities
# for modules to log, send/receive events, etc.
#
class Clusterized extends EventEmitter

  #
  # Module needs to override this function as an entry point to processing.
  #
  process: (callback) ->
    @log "module #{@name} needs to have a process(callback) function"

  #
  # Start the Module for scheduled execution
  #
  start: ->
    @log "starting #{@name}"

    # if an Agenda is defined, use it instead of sleep
    if @agenda
      @agenda.start()
    else
      # set a default
      @moduleSleep = 1000 unless @moduleSleep

      @stopped = false

      # private function for one iteration, used to wrap setTimeout to allow asynchronicity
      # while ensuring there is a sleep period
      iterate = =>
        unless @stopped
          if @processing
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
                @send 'clusterized.error', "error on run #{uid}: #{err} after #{elapsed}ms"
              else
                @log "completed run #{uid}, took: #{elapsed}ms"
              @log "sleeping for: #{@moduleSleep} ms"
              setTimeout ->
                iterate()
              , @moduleSleep

      # kick off iteration loop
      iterate()

  #
  # Stop Module and exit the process
  #
  stop: ->
    unless @stopped
      @stopped = true
      @log "#{@name} stopped processing"

    # stop Agenda if it was instantiated
    if @agenda
      @agenda.stop()

  #
  # Perform one iteration when this function is called
  #
  kick: (callback) ->
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
          @send 'clusterized.error', "error on kick ##{uid}: #{err} after #{elapsed}ms"
        else
          @log "completed kick ##{uid}, took: #{elapsed}ms"
        callback() if callback
    else
      @log "skipping kick because process() is already running"

  #
  # Send generic message to Master process
  #
  send: (event, msg) ->
    if event and msg
      process.send
        event: event
        message: msg

  #
  # Handle some built-in messages, emit the rest for module to handle
  #
  recv: (msg) ->
    switch msg.event
      when 'clusterized.start'
        @start()
      when 'clusterized.kick'
        @kick()
      when 'clusterized.stop'
        @stop()
      when 'clusterized.kill'
        process.exit()
      when 'clusterized.sleep'
        @moduleSleep = msg.message
      when 'clusterized.agenda'
        @setAgenda msg.message.db, msg.message.every
      else # emit for user's code
        @emit msg.event, msg.message

  #
  # Provide a way for Clusterized module to get logging back to Master
  #
  log: (msg) ->
    @send 'clusterized.log', msg

  #
  # Agenda integration, see `Clusterizer` docs for parameters
  #
  setAgenda: (db, every) ->
    @log "Agenda scheduling process every #{every}"
    # set the processEvery parameter to be the same as the execution frequency
    # up to 1 hour. After that, have Agenda check every hour.
    processEvery = every
    if humanInterval(every) > 3600000
      processEvery = "1 hour"
    # Set up Agenda.
    @agenda = new Agenda
      name: @name
      db:
        address: db
        collection: 'clusterizer'
      processEvery: processEvery
    @agenda.define "#{@name} - iterate", (job, done) =>
      unless @processing
        @kick ->
          done()
      else
        @log "skipping agenda job because process() is already running"
        done()
    @agenda.every(every, "#{@name} - iterate")

#
# Exports
#
module.exports = Clusterized
