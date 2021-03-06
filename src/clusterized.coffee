
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
          @iteration =>
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
  iteration: (callback) ->
    unless @processing
      uid = uuid.v1() # uid for this iteration
      @log "module iteration ##{uid}"
      timer.start(uid)
      # call module with a callback for it to call on exit
      @processing = true
      try
        @process (err) =>
          if timer
            elapsed = timer.stop(uid)
          @processing = false
          if err
            @send 'clusterized.error', "error on iteration ##{uid}: #{err} after #{elapsed}ms"
          else
            @log "completed iteration ##{uid}, took: #{elapsed}ms"
          callback() if callback
      catch e
        @error e
    else
      @log "skipping iteration because process() is already running"

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
        @iteration()
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
  # Send an error back to the Master
  #
  error: (e) ->
    process.send
      event: 'clusterized.error'
      name: e.name
      message: e.message
      stack: e.stack

  #
  # Agenda integration, see `Clusterizer` docs for parameters
  #
  setAgenda: (db, every) ->
    @log "Agenda scheduling process every #{every}"
    # set optimal processEvery based on 'every' parameter
    processEvery = humanInterval(every) # convert to ms
    if processEvery > 1000 and processEvery <= 3600000 # 1 second to 1 hour
      processEvery /= 4 # 1/4 the ms
    if processEvery > 3600000 and processEvery <= 86400000 # 1 hour to 1 day
      processEvery = "30 minutes"
    if processEvery > 86400000 # day and above, check every hour
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
        @iteration ->
          done()
      else
        @log "skipping agenda job because process() is already running"
        done()
    @agenda.every(every, "#{@name} - iterate")

#
# Exports
#
module.exports = Clusterized
