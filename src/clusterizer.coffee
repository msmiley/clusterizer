#!/usr/bin/env coffee

fs = require 'fs'
path = require 'path'
cluster = require 'cluster'
util = require 'util'
{ EventEmitter } = require 'events'

#
# The Clusterizer manages a set of Modules which inherit from Clusterized
#
class Clusterizer extends EventEmitter
  constructor: (@options={}) ->

    @options.logging ?= false

    if cluster.isMaster
      @modules = {}

      # load directory modules
      @clusterizeDirectory @options.dir

      # load npm modules
      @clusterizeNpmModules @options.npm

      # connect up all modules to the master
      @connect()

      # callback to inform us when a module dies
      cluster.on 'exit', (worker, code, signal) ->
        util.log "Module #{worker.process.pid} died" if @options.logging

    else # module process
      # set process name to match the name given to clusterizer
      @name = process.env.name
      process.title = "clusterizer - #{@name}"

      # get the name of the module this process will run
      @moduleName = process.env.module

      util.log "starting clusterized module: #{@moduleName}"
      # attempt to load
      Module = @loadModule @moduleName
      @module = new Module()
      # set module parameters
      @module.name = @name

      # start execution
      @module.start()

      process.on 'message', (msg) =>
        @module.recv msg

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
            when 'log' # take care of logging
              util.log "#{name}: #{msg.message}" if @options.logging
            else # emit for capture by user's code
              @emit msg.event, msg.message

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
  # Helper function to "require" a module
  #
  loadModule: (name) ->
    # try to load the module
    try
      return require name
    catch e
      util.error "Error loading Module: #{name}"
      return false

  #
  # Enable logging using util.log
  #
  enableLogging: ->
    @options.logging = true

module.exports = Clusterizer

#
# Main for every process. Identify the cluster master.
#
main = ->
  rizer = new Clusterizer
    logging: true
    dir: "../test_modules"

    # example broadcast
    setTimeout ->
      rizer.broadcast "test.event", "test message"
    , 2000

do main if require.main is module
