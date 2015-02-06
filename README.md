# Clusterizer

Clusterizer uses the Node.js cluster API to provide automatic clusterization of a single module, a directory of modules, or an array of npm module names.

The modules don't need to be performing the same task, as is usually the case with Node.js clusters. Clusterizer includes automatic scheduling of each process worker function using a variety of timing parameters.

Warning: work-in-progress, working for simple sleep timing

## Installation

```bash
$ npm install clusterizer
```

## Features

- automatic process management
- messaging to/from each process
- log aggregation to master process
- scheduling for process worker function
- graceful shutdown

## Usage

Look at `test_modules/module1.coffee` for an example module. Modules need to inherit from `Clusterized` and implement at least a `process(callback)` function. The class name (or constructor function name if in js) is irrelevant as long as it is a module-level export as shown below.

```coffee
{ Clusterized } = require 'clusterizer'

class Worker extends Clusterized
  process: (callback) ->
    # do something
    callback(err)

module.exports = Worker
```

Then instantiate a `Clusterizer` in your code. See the example `main` function in `clusterizer.coffee`. Use `.isMaster` as a check to prevent your other code from running in every process.

```coffee
{ Clusterizer } = require 'clusterizer'

clusterizer = new Clusterizer
  logging: true
  dir: ["../test_modules"]

# prevents this from running in every worker process
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

  # ... your code ...

```

Other forms of specifying worker modules in the `Clusterizer` options:

```coffee
file: ["../test_modules/module1.coffee", "../test_modules/module2.coffee"]
npm: ["clusterizer-test-module1", "clusterizer-test-module1"]
```

The `file:`, `dir:`, and `npm:` options can be used simultaneously.


- Duplicate modules are currently not supported
- More advanced process scheduling coming soon

## License

  [MIT](LICENSE)
