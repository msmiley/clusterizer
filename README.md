# Clusterizer

Clusterizer provides easy clusterization of a single module, a directory of modules, or an array of npm module names.

The modules don't need to be performing the same task, as is usually the case with Node.js clusters. Clusterizer includes simple sleep-type scheduling as well as advanced scheduling through [Agenda](https://www.npmjs.com/package/agenda).

## Installation

```bash
$ npm install clusterizer
```

## Features

- automatic process management
- messaging to/from each process
- log aggregation to master process
- built-in sleep-type scheduling for process worker function
- integration with [Agenda](https://www.npmjs.com/package/agenda) for advanced scheduling
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

if clusterizer.isMaster

  # example message handler
  clusterizer.on 'echo', (msg, module) ->
    console.log "\nGot #{msg} from #{module}\n"

  # modify sleep backoff time for all
  clusterizer.setSleep 500

  # modify sleep backoff for specific module
  clusterizer.setSleep 500, 'module2'

  # set agenda for all
  clusterizer.setAgenda 'localhost:27017/test', '3 seconds'

  # start all (prefers Agenda mode if an agenda was set)
  clusterizer.start()

  # example broadcast
  setTimeout ->
    clusterizer.broadcast "echo", "test broadcasted message"
  , 2000

  # example message to single module
  setTimeout ->
    clusterizer.send "module2", "echo", "call me back"
  , 4000

  # stops module1
  setTimeout ->
    clusterizer.stop('module1')
  , 6000

  # stops all
  setTimeout ->
    clusterizer.stop()
  , 8000

  # restart all
  setTimeout ->
    clusterizer.start()
  , 10000

  # kill all
  setTimeout ->
    clusterizer.kill()
  , 12000

  # ... your code ...

```

Other forms of specifying worker modules in the `Clusterizer` options:

```coffee
file: ["../test_modules/module1.coffee", "../test_modules/module2.coffee"]
npm: ["clusterizer-test-module1", "clusterizer-test-module1"]
```

The `file:`, `dir:`, and `npm:` options can be used simultaneously.

- Duplicate modules are currently not supported

### Advanced Scheduling

```coffee
setAgenda(database, every, name)
```

Use `setAgenda` to define a fuzzy execution frequency. Clusterizer uses [Agenda](https://www.npmjs.com/package/agenda) behind the scenes so the `database` and `every` parameters are what Agenda expects. For example, something like

```coffee
clusterizer.setAgenda 'localhost:27017/test', '3 seconds', 'module1'
```

If the `name` parameter isn't specified, Clusterizer will apply the agenda to all clusterized modules.

Calling `start()` once an Agenda has been defined will always use the agenda, not the sleep period.

## License

  [MIT](LICENSE)
