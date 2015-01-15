
uuid = require 'node-uuid'
{ EventEmitter } = require 'events'
timer = require 'metrics-timer'

#
# Base class for all clusterized modules. Provides facilities for modules to log,
# throw errors, time their execution, etc.
#
class Clusterized extends EventEmitter
  # @property [Number] The execution interval in milliseconds
  averageT: undefined
  defaultSleep: 5000

  constructor: ->
    # save off the class name
    @NAME = @constructor.name
    @sleep = @defaultSleep
    @averageT = null

    # let module initialize
    @init()

  #
  # Start Module
  #
  start: ->
    @log "starting"

    @stopped = false

    # private function for one iteration, used to wrap setTimeout to allow asynchronicity
    # while ensuring there is a sleep period and a chance to change @stopped
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
          @process (err) =>
            elapsed = timer.stop(uid)
            if err
              @error "error on run #{uid}: #{err} after #{elapsed}ms"
            else
              @log "completed run #{uid}, took: #{elapsed}ms"
            iterate()
      , @sleep

    # kick off iteration loop
    iterate()

  #
  # Stop Module
  #
  stop: ->
    @stopped = true

  #
  # Notification of an event for this Module.
  # @param msg [Object] The event object received for this Module
  #
  notify: (msg) ->
    if msg.name is @NAME and msg.conf and msg.value
      @log "changing conf: #{msg.conf} = #{msg.value}"
      @conf[msg.conf] = msg.value

  #
  # Post event from module to master
  # @param tag [String] Tag representing the type/meaning of data
  # @param data [Object] Any object to send
  #
  post: (regarding, level, message, detail) ->
    @emit 'post',
      tag: 'event'
      data:
        date: new Date()
        src: @NAME
        re: regarding
        level: level
        msg: message
        detail: detail

  #
  # Send data from module
  # @param tag [String] Tag representing the type/meaning of data
  # @param data [Object] Any object to send
  #
  send: (tag, data) ->
    @emit 'send',
      tag: tag
      data: data

  #
  # Log message
  # @param msg [String] The log message
  #
  log: (msg) ->
    @emit 'log', "#{@NAME}: #{msg}"
  
  #
  # Throw an error
  # @param msg [String] The error message
  #
  error: (msg) ->
    @emit 'error', "#{@NAME}: #{msg}"
  
  #
  # Start the execution timer. Timer is provided
  # by the Analytics base class as a convenience to
  # analysis modules. An id must be provided to track
  # concurrent timers and can be any Object.
  # @param id [Object] The id of this timer
  #
  tic: (id) ->
    timer.start(id)
  
  #
  # Stop the execution timer. Timer is provided
  # by the Analytics base class as a convenience to
  # analysis modules. The id provided must have been already used
  # with a corresponding tic() call.
  # @param id [Object] The id of the running timer
  #
  toc: (id) ->
    try
      timer.stop(id)
    catch e
      if e.name is "TypeError" # handle this one since it's a result of no tic() for this toc()
        throw new Error("toc(#{id}) called without previously calling tic(#{id}), or toc(#{id}) has already been called")
      throw e

#
# Exports
#
module.exports = Clusterized