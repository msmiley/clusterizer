
fs = require 'fs'
path = require 'path'
cluster = require 'cluster'
util = require 'util'
{ EventEmitter } = require 'events'


class Clusterizer extends EventEmitter
  constructor: ->
    @logging = false
    @isMaster = cluster.isMaster

    if @isMaster
      # callback to inform us when a worker dies
      cluster.on 'exit', (worker, code, signal) ->
        util.log "worker #{worker.process.pid} died" if @logging

      # provide message passing from workers
      Object.keys(cluster.workers).forEach (id) ->
        cluster.workers[id].on 'message', (msg) ->
          @emit 'message', msg

    else
      # set process name to match the name given to clusterizer
      @name = process.env.name
      process.title = "#{@name}"

      # get the name of the module this process will run
      @moduleName = process.env.module

      process.on 'message', (msg) ->
        util.log msg

  clusterizeDirectory: (dir) ->
    util.log "Clusterizing modules in directory: #{dir}" if @logging
    # fork a process for each module in the path
    require('fs').readdirSync(dir).forEach (file) ->
      if file.match /\.js|coffee$/
        util.log "forking process to handle #{file}" if @logging
        cluster.fork
          module: file

  clusterizeNpmModules: (list) ->
    for mod in list
      util.log "forking process to handle #{mod}" if @logging
      cluster.fork
        module: mod

  loadModule: (name) ->
    # try to load the module
    try
      return require name
    catch e
      util.error "Error loading Module: #{name}"


  enableLogging: ->
    @logging = true

  clusterized: ->
    util.log "starting clusterized module" if @logging

module.exports = new Clusterizer()

#
# Main for every process. Identify the cluster master.
#
main = ->
  rized = require './clusterized'

  rizer = new Clusterizer()
  rizer.enableLogging()

  if rizer.isMaster
    rizer.clusterizeDirectory("../test_modules")
  else
    rizer.clusterized()


do main if require.main is module
