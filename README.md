# Clusterizer

Clusterizer uses the Node.js cluster API to provide automatic clusterization of either a directory of modules or an array of npm module names.

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

Look at test_modules/module1.coffee for an example module. Modules need to inherit from Clusterized and implement at least a `process(callback)` function.

```coffee
{ Clusterized } = require 'clusterizer'

class Worker extends Clusterized
  process: (callback) ->
    # do something
    callback(err)
```

Then simply instantiate a `Clusterizer` in your code. See the example `main` function in `clusterizer.coffee`.

```coffee
clusterizer = new Clusterizer
  logging: true
  dir: "../test_modules"

clusterizer.broadcast "test.event", "test message"
clusterizer.send "module1", "test.event", "test message"

clusterizer.on 'message' ->

```

More advanced scheduling coming soon.

## License

  [MIT](LICENSE)
