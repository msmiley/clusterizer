# Clusterizer

Clusterizer uses the Node.js cluster API to provide automatic clusterization of either a directory of modules or an array of npm module names.

The modules don't need to be performing the same task, as is usually the case with Node.js clusters. Clusterizer includes automatic scheduling of each process worker function using a variety of timing parameters.

Warning: work-in-progress

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

```coffee
{ Clusterized } = require 'clusterizer'

class Worker extends Clusterized

```

## License

  [MIT](LICENSE)