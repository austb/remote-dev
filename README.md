# Scripts for Remote Testing/Development

## Prerequisites

* `bolt`
* `vmfloaty`
* `jq`

## Getting started

Install the necessary modules with
```
bolt puppetfile install
```

## Available scripts

The scripts live in `lib/`.

### `foss-master`

Install an Open Source Monolithic master on a vmpooler node. Run with `--help`
to see the available options.
