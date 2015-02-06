#!/usr/bin/env coffee

#
# The Clusterizer manages execution and communication with a set of Modules which inherit from Clusterized.
# All setup is performed through the options parameter to the constructor.
#

fs = require 'fs'
path = require 'path'
cluster = require 'cluster'
util = require 'util'
{ EventEmitter } = require 'events'

# ### Options
#
# - logging [Boolean] Enables logging to util.log
# - dir [String] Directory of modules to clusterize
# - npm [Array] Array of npm module names to clusterize
#
class Clusterizer extends EventEmitter
  constructor: (@options={}) ->
    # Flag used to prevent user code from running in every process
    @isMaster = cluster.isMaster

    # Logging is disabled by default
    @options.logging ?= false

    # Master Clusterizer
    if cluster.isMaster
      @modules = {}

      # load directory modules
      @clusterizeDirectory @options.dir

      # load npm modules
      @clusterizeNpmModules @options.npm

      # connect up all modules to the master
      @connect()

      # callback to inform us when a module dies
      cluster.on 'exit', (worker, code, signal) =>
        for own name,proc of @modules
          if proc.id is worker.id
            util.log "Module #{name} died" if @options.logging
            delete @modules[name]
            # emit event that a module died
            @emit 'died', name

    # Clusterized process
    else
      # set process name to match the name given to clusterizer
      @name = process.env.name
      process.title = "clusterizer - #{@name}"

      # get the name of the module this process will run
      @moduleName = process.env.module

      util.log "starting clusterized module: #{@moduleName}" if @options.logging

      # load and instantiate the module
      Module = @loadModule @moduleName

      # make sure module has a process() function
      if typeof(Module.prototype.process) is 'function'
        @module = new Module()
        # set module parameters
        @module.name = @name

        # pass messages received from master to the Clusterized module
        process.on 'message', (msg) =>
          @module.recv msg
      else
        util.error "Module #{@name} does not have valid process() function"

  #
  # Clusterize a directory of modules which inherit from Clusterized
  #
  clusterizeDirectory: (dir) ->
    if dir
      util.log "Clusterizing modules in directory: #{dir}" if @options.logging
      # fork a process for each module in the path
      require('fs').readdirSync(dir).forEach (file) =>
        if file.match /\.js|coffee$/
          # strip off extension for name
          name = path.basename file, path.extname(file)
          util.log "forking process to handle #{name}" if @options.logging
          @modules[name] = @fork name, path.join(dir, file)

  #
  # Clusterize a list of installed npm modules which inherit from Clusterized
  #
  clusterizeNpmModules: (list) ->
    if list
      for mod in list
        # make sure npm module is accessible before forking
        if @loadModule mod
          util.log "forking process to handle #{mod}" if @options.logging
          @modules[mod] = @fork mod, mod

  #
  # Connect to all Clusterized modules for message passing
  #
  connect: ->
    for own name,proc of @modules
      do (name,proc) => # capture scope
        cluster.workers[proc.id].on 'message', (msg) =>
          switch msg.event
            when 'clusterized.log' # take care of logging
              util.log "#{name}: #{msg.message}" if @options.logging
              # Emit log message and the module which produced it
              @emit 'log', msg.message, name
            else
              # Emit the event for capture by user's code along with the name of the module
              @emit msg.event, msg.message, name

  #
  # Send message to the specified module
  #
  send: (name, event, message) ->
    if @modules[name]
      @modules[name].send
        event: event
        message: message

  #
  # Broadcast a message to all modules
  #
  broadcast: (event, message) ->
    for own name,proc of @modules
      proc.send
        event: event
        message: message

  #
  # Fork a cluster process with the necessary parameters
  #
  fork: (name, mod) ->
    cluster.fork
      name: name
      module: mod

  #
  # Helper function to "require" a module. Needs the full path to the module for single file modules
  # or the npm module name. npm modules should already be installed.
  #
  loadModule: (name) ->
    # try to load the module
    try
      return require name
    catch e
      util.error "Error loading Module: #{name}"
      return false

  #
  # Start a module or all modules if a name is not provided
  #
  start: (name) ->
    if name is undefined
      @broadcast 'clusterized.start'
    else if @modules[name]
      @send name, 'clusterized.start'

  #
  # Kick a module to process once, or all modules if a name is not provided
  #
  kick: (name) ->
    if name is undefined
      @broadcast 'clusterized.kick'
    else if @modules[name]
      @send name, 'clusterized.kick'

  #
  # Stop a module or all modules if a name is not provided
  #
  stop: (name) ->
    if name is undefined
      @broadcast 'clusterized.stop'
    else if @modules[name]
      @send name, 'clusterized.stop'

  #
  # Kill a module or all modules if a name is not provided
  #
  kill: (name) ->
    if name is undefined
      @broadcast 'clusterized.kill'
    else if @modules[name]
      @send name, 'clusterized.kill'

  #
  # Enable logging using util.log
  #
  enableLogging: ->
    @options.logging = true

#
# Exports
#
module.exports = Clusterizer

#
# Example Main
#
main = ->
  clusterizer = new Clusterizer
    logging: true
    dir: "../test_modules"

  if clusterizer.isMaster
    # start all
    clusterizer.start()

    # example broadcast
    setTimeout ->
      clusterizer.broadcast "echo", "test broadcasted message"
    , 2000

    # example message to single module
    setTimeout ->
      clusterizer.send "module2", "echo", "call me back"
    , 4000

    # example message handler
    clusterizer.on 'echo', (msg, module) ->
      console.log "\nGot #{msg} from #{module}\n"

    # stops module1
    setTimeout ->
      clusterizer.stop('module1')
    , 6000

    # stops all
    setTimeout ->
      clusterizer.stop()
    , 6000

    # restart all
    setTimeout ->
      clusterizer.start()
    , 8000

    # kill all
    setTimeout ->
      clusterizer.kill()
    , 10000

do main if require.main is module
