# In this repo

- Setup run postgresql
- Setup DBT
- Run DBT

# Prerequisites

- Python and Virtual environment
- Docker compose

# Create Postgre Docker Compose

Create a file named `docker-compose.yml`.

Click [here](docker-compose.yml) to see the content

# Start Postgre Docker Compose

```bash
docker compose up -d
```

You can now access postgre at `localhost:15432`

- User: `postgres`
- Password: `pass`

# Setup venv and install DBT

```bash
python -m venv .venv
source .venv/bin/activate
pip install dbt-postgres # Note: DBT has many DBMS adapter
```

You only need to run this once. Next time you want to activate the venv, you can invoke `source ./venv/bin/activate`


# Create requirements.txt

In order to keep track what packages you have installed, it is better to make an up-to-date list of `requirements.txt`.

You can list your dbt-related packages by invoking


```bash
pip freeze | grep dbt
```

The output will be similar to:

```
dbt-core==1.6.3
dbt-extractor==0.4.1
dbt-postgres==1.6.3
dbt-semantic-interfaces==0.2.0
```

Put the list into `requirements.txt`.

If you need to install other packages, you should add them into `requirements.txt` as well

Next time you want to install `dbt`, you can simply run `pip install -r requirements.txt`

# Setup DBT project

> Note: Project name should be a valid python package name (i.e: written in snake_case)

```bash
dbt init my_project
```

Make sure to choose the correct database (in this case postgres)

# Setup DBT Profile

By default, DBT will create a dbt profile at your home directory `~/.dbt/profiles.yml`

You can update the profiles, or you can make a new dbt-profile directory.

To make a new dbt-profie directory, you can invoke the following:

```bash
mkdir dbt-profiles
touch dbt-profiles/profiles.yml
export DBT_PROFILES_DIR=$(pwd)/dbt-porfiles
```

You can set your `profiles.yml` as follow:

```yml
my_project:
  outputs:

    dev:
      type: postgres
      threads: 1
      host: localhost
      port: 15432
      user: postgres
      pass: pass
      dbname: coba
      schema: public

  target: dev

```

Always remember to set `DBT_PROFILES_DIR` everytime you want to work with DBT. Otherwise, you should add `--profiles-dir` option everytime you run DBT. 

Please refer to [DBT profile documentation](https://docs.getdbt.com/docs/core/connect-data-platform/connection-profiles) for more information.

# Exploring DBT Configurations


