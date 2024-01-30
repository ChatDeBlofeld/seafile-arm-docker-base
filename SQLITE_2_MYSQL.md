# Migration guide

Since Seafile 11, sqlite support is deprecated in Seafile itself (see [announcement](https://forum.seafile.com/t/major-changes-in-seafile-version-11-0/18474#deprecating-sqlite-database-support-5)) and **removed** in this image.

## Prerequisites

To make writing easier, this guide supposes you're using [my compose topology](https://github.com/ChatDeBlofeld/seafile-arm-docker/tree/3e6bd8a976fa24d946ec5f7b8471004fb6c63303) in the condition of commit `3e6bd8a976fa24d946ec5f7b8471004fb6c63303`. You should pull it if you can. 

There's no black magic though, if your configuration is too far from the recommended one, you can read through [this script](./scripts/sqlite2mysql.sh) that contains all steps.

> **WARNING: Backup your db and conf folders.** You've been warned.

## Dump

Go in your installation directory and stop everything:

```bash
./compose.sh down -v
```

Move your `db` folder (containing the sqlite files) to `sqlite`:

```bash
mv db sqlite
```

Change the seafile image tag to `11` and add a database service in your compose file. When using my configuration, it only means the following changes in your dotenv:

```
# MariaDB
DBMS=1
SEAFILE_IMAGE=franchetti/seafile-arm:11
```

Then dump the databases:

```bash
./compose.sh run --rm -v $(pwd)/sqlite:/shared/sqlite seafile sqlite2mysql
```

## Restore

It's time to run your dbms:

```shell
./compose.sh up -d db
```

You'll have to wait until it's ready, you can use `./compose.sh logs -f db`. Obviously, the dbms is ready when it's written `done`.

Say your first prayer and restore your databases (type the mysql `root` user password when asked):

```bash
./compose.sh run --rm -v $(pwd)/sqlite:/sqlite --entrypoint /sqlite/restore.sh db
```

Say your second prayer and run seafile:

```bash
./compose.sh up -d
```

That's it, you can now remove the `sqlite` folder.

If restoration failed, try to get help on [seafile forums](https://forum.seafile.com).