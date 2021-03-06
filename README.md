# docker-airflow

### Pandas or numpy or any of data science projects build time increase when using pip install <data science package) with alphine

Below links discuss about why it is taking more time for building the docker image,

https://news.ycombinator.com/item?id=22182226

https://stackoverflow.com/questions/49037742/why-does-it-take-ages-to-install-pandas-on-alpine-linux

https://pythonspeed.com/docker/ (They are suggesting alphine image is not a good candidate for production)

https://stackoverflow.com/questions/49037742/why-does-it-take-ages-to-install-pandas-on-alpine-linux/50443531#50443531

We can use alphine but we have to download and give reference to packages needed, refer the below mentioned link,
https://github.com/astronomer/ap-airflow

While building the pandas, numpy and other python scientific libraries, alphine image taking much amount of time to build. This is due to usuage of musl-dev library, busybox instead of glibc(debian,fedora,ubuntu are using). Debian, ubuntu, etc python pip will directly fetch the python wheel of particular package. Alphine fetches the source code and then make the wheel for building the image. So Alphine is not suggested(refer https://pythonspeed.com/docker/)



## Informations

* Based on Python (3.7-slim-buster) official Image [python:3.7-slim-buster](https://hub.docker.com/_/python/) and uses the official [Postgres](https://hub.docker.com/_/postgres/) as backend and [Redis](https://hub.docker.com/_/redis/) as queue
* Install [Docker](https://www.docker.com/)
* Install [Docker Compose](https://docs.docker.com/compose/install/)
* Following the Airflow release from [Python Package Index](https://pypi.python.org/pypi/apache-airflow)

## Installation

Pull the image from the Docker repository.

    docker pull docker-airflow

## Build

Optionally install [Extra Airflow Packages](https://airflow.incubator.apache.org/installation.html#extra-package) and/or python dependencies at build time :

    docker build --rm --build-arg AIRFLOW_DEPS="datadog,dask" -t docker-airflow .
    docker build --rm --build-arg PYTHON_DEPS="flask_oauthlib>=0.9" -t docker-airflow .

or combined

    docker build --rm --build-arg AIRFLOW_DEPS="datadog,dask" --build-arg PYTHON_DEPS="flask_oauthlib>=0.9" -t docker-airflow .

Don't forget to update the airflow images in the docker-compose files to docker-airflow:latest.

## Usage

By default, docker-airflow runs Airflow with **SequentialExecutor** :

    docker run -d -p 8080:8080 docker-airflow webserver

If you want to run another executor, use the other docker-compose.yml files provided in this repository.

For **LocalExecutor** :

    docker-compose -f docker-compose-LocalExecutor.yml up -d

For **CeleryExecutor** :

    docker-compose -f docker-compose-CeleryExecutor.yml up -d

NB : If you want to have DAGs example loaded (default=False), you've to set the following environment variable :

`LOAD_EX=n`

    docker run -d -p 8080:8080 -e LOAD_EX=y docker-airflow

If you want to use Ad hoc query, make sure you've configured connections:
Go to Admin -> Connections and Edit "postgres_default" set this values (equivalent to values in airflow.cfg/docker-compose*.yml) :
- Host : postgres
- Schema : airflow
- Login : airflow
- Password : airflow

For encrypted connection passwords (in Local or Celery Executor), you must have the same fernet_key. By default docker-airflow generates the fernet_key at startup, you have to set an environment variable in the docker-compose (ie: docker-compose-LocalExecutor.yml) file to set the same key accross containers. To generate a fernet_key :

    docker run docker-airflow python -c "from cryptography.fernet import Fernet; FERNET_KEY = Fernet.generate_key().decode(); print(FERNET_KEY)"

## Configuring Airflow

It's possible to set any configuration value for Airflow from environment variables, which are used over values from the airflow.cfg.

The general rule is the environment variable should be named `AIRFLOW__<section>__<key>`, for example `AIRFLOW__CORE__SQL_ALCHEMY_CONN` sets the `sql_alchemy_conn` config option in the `[core]` section.

Check out the [Airflow documentation](http://airflow.readthedocs.io/en/latest/howto/set-config.html#setting-configuration-options) for more details

You can also define connections via environment variables by prefixing them with `AIRFLOW_CONN_` - for example `AIRFLOW_CONN_POSTGRES_MASTER=postgres://user:password@localhost:5432/master` for a connection called "postgres_master". The value is parsed as a URI. This will work for hooks etc, but won't show up in the "Ad-hoc Query" section unless an (empty) connection is also created in the DB

## Custom Airflow plugins

Airflow allows for custom user-created plugins which are typically found in `${AIRFLOW_HOME}/plugins` folder. Documentation on plugins can be found [here](https://airflow.apache.org/plugins.html)

In order to incorporate plugins into your docker container
- Create the plugins folders `plugins/` with your custom plugins.
- Mount the folder as a volume by doing either of the following:
    - Include the folder as a volume in command-line `-v $(pwd)/plugins/:/usr/local/airflow/plugins`
    - Use docker-compose-LocalExecutor.yml or docker-compose-CeleryExecutor.yml which contains support for adding the plugins folder as a volume

## Install custom python package

- Create a file "requirements.txt" with the desired python modules
- Mount this file as a volume `-v $(pwd)/requirements.txt:/requirements.txt` (or add it as a volume in docker-compose file)
- The entrypoint.sh script execute the pip install command (with --user option)

## UI Links

- Airflow: [localhost:8080](http://localhost:8080/)
- Flower: [localhost:5555](http://localhost:5555/)


## Scale the number of workers

Easy scaling using docker-compose:

    docker-compose -f docker-compose-CeleryExecutor.yml scale worker=5

This can be used to scale to a multi node setup using docker swarm.

## Running other airflow commands

If you want to run other airflow sub-commands, such as `list_dags` or `clear` you can do so like this:

    docker run --rm -ti docker-airflow airflow list_dags

or with your docker-compose set up like this:

    docker-compose -f docker-compose-CeleryExecutor.yml run --rm webserver airflow list_dags

You can also use this to run a bash shell or any other command in the same environment that airflow would be run in:

    docker run --rm -ti docker-airflow bash
    
    docker run --rm -ti docker-airflow ipython

# Simplified SQL database configuration using PostgreSQL

If the executor type is set to anything else than *SequentialExecutor* you'll need an SQL database.
Here is a list of PostgreSQL configuration variables and their default values. They're used to compute
the `AIRFLOW__CORE__SQL_ALCHEMY_CONN` and `AIRFLOW__CELERY__RESULT_BACKEND` variables when needed for you
if you don't provide them explicitly:

| Variable            | Default value |  Role                |
|---------------------|---------------|----------------------|
| `POSTGRES_HOST`     | `postgres`    | Database server host |
| `POSTGRES_PORT`     | `5432`        | Database server port |
| `POSTGRES_USER`     | `airflow`     | Database user        |
| `POSTGRES_PASSWORD` | `airflow`     | Database password    |
| `POSTGRES_DB`       | `airflow`     | Database name        |
| `POSTGRES_EXTRAS`   | empty         | Extras parameters    |

You can also use those variables to adapt your compose file to match an existing PostgreSQL instance managed elsewhere.

Please refer to the Airflow documentation to understand the use of extras parameters, for example in order to configure
a connection that uses TLS encryption.

Here's an important thing to consider:

> When specifying the connection as URI (in AIRFLOW_CONN_* variable) you should specify it following the standard syntax of DB connections,
> where extras are passed as parameters of the URI (note that all components of the URI should be URL-encoded).

Therefore you must provide extras parameters URL-encoded, starting with a leading `?`. For example:

    POSTGRES_EXTRAS="?sslmode=verify-full&sslrootcert=%2Fetc%2Fssl%2Fcerts%2Fca-certificates.crt"

# Simplified Celery broker configuration using Redis

If the executor type is set to *CeleryExecutor* you'll need a Celery broker. Here is a list of Redis configuration variables
and their default values. They're used to compute the `AIRFLOW__CELERY__BROKER_URL` variable for you if you don't provide
it explicitly:

| Variable          | Default value | Role                           |
|-------------------|---------------|--------------------------------|
| `REDIS_PROTO`     | `redis://`    | Protocol                       |
| `REDIS_HOST`      | `redis`       | Redis server host              |
| `REDIS_PORT`      | `6379`        | Redis server port              |
| `REDIS_PASSWORD`  | empty         | If Redis is password protected |
| `REDIS_DBNUM`     | `1`           | Database number                |

You can also use those variables to adapt your compose file to match an existing Redis instance managed elsewhere.

# Dockerfile Creation Tips

https://itnext.io/how-to-use-docker-multi-stage-build-to-create-optimal-images-for-dev-and-production-568c19a39de8

https://blog.gds-gov.tech/writing-effective-docker-images-more-efficiently-bf0129c3293b

https://github.com/apache/airflow/issues/8605

https://medium.com/@xnuinside/quick-tutorial-apache-airflow-with-3-celery-workers-in-docker-composer-9f2f3b445e4

https://github.com/barrachri/easy-airflow

https://hub.docker.com/r/drunkar/airflow-alpine/dockerfile

# Dockerfile LOg Rotator and Retention

https://github.com/teamclairvoyant/airflow-maintenance-dags/blob/master/log-cleanup/airflow-log-cleanup.py

https://github.com/teamclairvoyant/airflow-maintenance-dags/tree/master/db-cleanup

https://github.com/teamclairvoyant/airflow-maintenance-dags/tree/master/log-cleanup

https://github.com/astronomer/ap-airflow/blob/master/1.10.12/alpine3.10/include/clean-airflow-logs

# Redis Warnings fix
https://stackoverflow.com/questions/11342167/how-to-increase-ulimit-on-amazon-ec2-instance

https://github.com/redis/redis/issues/3166

#### Main Reference for Redis Issue:

https://stackoverflow.com/questions/40683285/max-file-descriptors-4096-for-elasticsearch-process-is-too-low-increase-to-at

https://stackoverflow.com/questions/46771233/max-file-descriptors-for-elasticsearch-process-is-too-low 

https://github.com/redis/redis/issues/6123

https://github.com/docker-library/redis/issues/35

https://stackoverflow.com/questions/56297979/redis-5-0-5-warning-the-tcp-backlog-setting-of-511-cannot-be-enforced-because

https://stackoverflow.com/questions/39329732/specify-sysctl-values-using-docker-compose

https://serverfault.com/questions/716982/how-to-raise-max-no-of-file-descriptors-for-daemons-running-on-debian-jessie

https://stackoverflow.com/questions/30063907/using-docker-compose-how-to-execute-multiple-commands

https://github.com/bkuhl/redis-overcommit-on-host

http://blog.cspub.net/post/7

https://github.com/jghoman/awesome-apache-airflow/blob/master/README.md

https://eng.lyft.com/running-apache-airflow-at-lyft-6e53bb8fccff

https://vitux.com/how-to-install-vim-editor-on-debian/

https://askubuntu.com/questions/988266/systemctl-command-not-found-on-ubuntu-16-04

https://r-future.github.io/post/how-to-fix-redis-warnings-with-docker

https://github.com/artsy/echo/blob/master/docker-compose.yml


