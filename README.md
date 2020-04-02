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

## VMPooler Scripts

All VMPooler-specific utilities live in `bin/vmpooler`.

### `foss-master`

Install an Open Source Monolithic master on a vmpooler node. Run with `--help`
to see the available options.

**NOTE** This will try to initialize PuppetDB with an SSL connection to
Postgres, which is currently broken for Debian-based OSes. Remove all the URI
params from `subname` in `database.ini` to allow for a plaintext pgjdbc
connection on Debian-based OSes.
