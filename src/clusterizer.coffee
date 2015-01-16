
cluster = require 'cluster'




class Clusterizer




#
# Main for every process. Identify the cluster master.
#
main = ->
  Clusterized = require './clusterized'

  if cluster.isMaster
    e = new Clusterizer()
  else
    mgw = new MeshGateway()

do main if require.main is module
