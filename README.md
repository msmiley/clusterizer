# Clusterizer

Instant clusterization of an array of module paths, a directory of modules, or an array of npm module names.

Modules don't need to be performing the same task, as is usually the case with Node.js clusters. Clusterizer excels at offloading long-running operations into another process and scheduling them intelligently.

Clusterizer includes built-in sleep-type scheduling as well as advanced scheduling through [Agenda](https://www.npmjs.com/package/agenda).

## Installation

```bash
$ npm install clusterizer
```

## Features

- automatic process forking
- events to/from each module
- log/error aggregation to master process
- built-in sleep-type scheduling
- integration with [Agenda](https://www.npmjs.com/package/agenda) for advanced scheduling
- graceful shutdown

## Usage

See `test_modules/module1.coffee` for an example module. Modules need to inherit from `Clusterized` and implement at least a `process(callback)` function. The class name (or constructor function name if in js) is irrelevant as long as it is a module-level export as shown below.

```coffee
{ Clusterized } = require 'clusterizer'

class Worker extends Clusterized
  process: (callback) ->
    # do something
    callback(err)

module.exports = Worker
```

Then instantiate a `Clusterizer` in your code with an options object. See the example `main` function in `clusterizer.coffee`. Use `.isMaster` as a check to prevent your other code from running in every process.

```coffee
{ Clusterizer } = require 'clusterizer'

clusterizer = new Clusterizer
  logging: true
  dir: ["../test_modules"]

if clusterizer.isMaster

  # example log handler
  clusterizer.on 'log', (msg, module) ->
    console.log "LOG : #{module} : #{msg}"

  # example error handler, err object contains fields
  # similar to Error, i.e. name, message, stack
  clusterizer.on 'error', (err, module) ->
    console.error "ERROR : #{module} : #{err.stack}"

  # example user-defined message handler
  clusterizer.on 'echo', (msg, module) ->
    console.log "\nGot #{msg} from #{module}\n"

  # modify sleep backoff time for all
  clusterizer.setSleep 500

  # modify sleep backoff for specific module
  clusterizer.setSleep 500, 'module2'

  # set agenda for all
  clusterizer.setAgenda 'localhost:27017/test', '3 seconds'

  # set agenda for one
  clusterizer.setAgenda 'localhost:27017/test', '3 seconds', 'module1'

  # start all (uses Agenda mode for any module which has an agenda set)
  clusterizer.start()

  # broadcast event to all modules
  clusterizer.send "echo", "test broadcasted message"
  # or
  clusterizer.broadcast "echo", "test broadcasted message"

  # event with message to single module
  clusterizer.send "echo", "call me back", "module2"

  # event with no message to single modules
  clusterizer.send "echo", null, "module2"

  # stops module1
  clusterizer.stop 'module1'

  # stops all
  clusterizer.stop()

  # restart all
  clusterizer.start()

  # kill all
  clusterizer.kill()

  # ... your code ...

```

Other forms of specifying worker modules in the `Clusterizer` options:

```coffee
file: ["../test_modules/module1.coffee", "../test_modules/module2.coffee"]
npm: ["clusterizer-test-module1", "clusterizer-test-module1"]
```

#### Note

- the `file:`, `dir:`, and `npm:` options can be used simultaneously
- duplicate modules are currently not supported
- the 'error' event is emitted, so it needs to have a listener or an unspecified error will be thrown
- any errors thrown in clusterized modules will be emitted by the clusterizer with a full stack trace

### Advanced Scheduling

```coffee
setAgenda(database, every, name)
```

Use `setAgenda` to define a fuzzy execution frequency. Clusterizer uses [Agenda](https://www.npmjs.com/package/agenda) behind the scenes so the `database` and `every` parameters are what Agenda expects. For example, something like

```coffee
clusterizer.setAgenda 'localhost:27017/test', '3 seconds', 'module1'
```

If the `name` parameter isn't specified, Clusterizer will apply the agenda to all clusterized modules.

Calling `start()` once an Agenda has been defined for a module will always use the agenda, not the sleep period.

A module can call `setAgenda()` on itself if the db address is fixed or handed in using a message. This allows each module to specify its preferred schedule.

## License

  [MIT](LICENSE)
