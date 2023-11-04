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

You can now access postgre at `localhost:5432`

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
export DBT_PROFILES_DIR=$(pwd)/dbt-profiles
```

You can set your `profiles.yml` as follow:

```yml
my_project:
  outputs:

    dev:
      type: postgres
      threads: 1
      host: localhost
      port: 5432
      user: postgres
      pass: pass
      dbname: store
      schema: public

  target: dev

```

Always remember to set `DBT_PROFILES_DIR` everytime you want to work with DBT. Otherwise, you should add `--profiles-dir` option everytime you run DBT. 

Please refer to [DBT profile documentation](https://docs.getdbt.com/docs/core/connect-data-platform/connection-profiles) for more information.

# Setup DBT Project configuration

To setup DBT project configuration, you can edit `my_project/dbt_project.yml`.

Make sure your `models` looks like this:

```yml
models:
  my_project:
    # Config indicated by + and applies to all files under models/example/
    store:
      +schema: public
      +database: store
    store_analytics:
      +materialized: table
      +schema: analytics
      +database: store
```

The configuration tells you that:

- You have two folders under `models` directory:
  - `store`
  - `store_analytics`
- Every model in your `store` directory by default is corresponding to `store.public` schema.
- Every model in your `store_analytics` directory by default is
  - Corresponding to `store.analytics` schema
  - Materialized into `table`

Notice that every key started with `+` are configurations.

# Defining Source

To define source, you can put the following YAML into `models/store/schema.yml`

```yml
version: 2

sources:
  - name: store
    database: store
    schema: public

    tables:
      - name: brands
        columns:
          - name: brand_id
            description: "Unique identifier for each brand"
            tests:
              - unique
              - not_null
          - name: name
            description: "Name of the brand"
            tests:
              - not_null

      - name: products
        columns:
          - name: product_id
            description: "Unique identifier for each product"
            tests:
              - unique
              - not_null
          - name: brand_id
            description: "Foreign key referencing brands"
            tests:
              - relationships:
                  to: source('store', 'brands')
                  field: brand_id
          - name: name
            description: "Name of the product"
            tests:
              - not_null
          - name: price
            description: "Price of the product"
            tests:
              - not_null

      - name: orders
        columns:
          - name: order_id
            description: "Unique identifier for each order"
            tests:
              - unique
              - not_null
          - name: order_date
            description: "Date and time the order was placed"
            tests:
              - not_null

      - name: order_details
        columns:
          - name: order_detail_id
            description: "Unique identifier for each order detail"
            tests:
              - unique
              - not_null
          - name: order_id
            description: "Foreign key referencing orders"
            tests:
              - relationships:
                  to: source('store', 'orders')
                  field: order_id
          - name: product_id
            description: "Foreign key referencing products"
            tests:
              - relationships:
                  to: source('store', 'products')
                  field: product_id
          - name: quantity
            description: "Quantity of the product ordered"
            tests:
              - not_null
          - name: price
            description: "Price of the product in the order"
            tests:
              - not_null
```

This define your existing tables, as well as some tests to ensure data quality

Notice that you can use `source('<source-name>', '<table>')` to refer to any table in your source.

# Creating a Model

Now you can define a new model under `models/store_analytics` folder.

First, you need to define the `schema.yml`:

```yml
version: 2

models:
  - name: daily_sales
    description: "Aggregated sales metrics per day"
    columns:
      - name: order_date
        description: "The date of the orders"
        tests:
          - not_null
      - name: total_quantity
        description: "Total quantity of products sold"
        tests:
          - not_null
      - name: total_revenue
        description: "Total revenue for the day"
        tests:
          - not_null
```

You can define as much as models as you need, but in this example, we only create a single model named `daily_sales`.

You can then define a `daily_sales.sql` under the same directory:

```sql
WITH base AS (
    SELECT
        DATE(orders.order_date) AS order_date,
        order_details.quantity,
        order_details.price
    FROM
        {{ source('store', 'orders') }} AS orders
    JOIN
        {{ source('store', 'order_details') }} AS order_details
    ON
        orders.order_id = order_details.order_id
),

aggregated_sales AS (
    SELECT
        order_date,
        SUM(quantity) AS total_quantity,
        SUM(price) AS total_revenue
    FROM
        base
    GROUP BY
        order_date
)

SELECT
    *
FROM
    aggregated_sales
ORDER BY
    order_date
```

The model basically turns your `order_details` into `daily_sales` table.

Let break it down a little bit:

## Joining order and order details

```sql
SELECT
        DATE(orders.order_date) AS order_date,
        order_details.quantity,
        order_details.price
    FROM
        {{ source('store', 'orders') }} AS orders
    JOIN
        {{ source('store', 'order_details') }} AS order_details
    ON
        orders.order_id = order_details.order_id
```

First, you need to access the sources you define in the previous step. You can use `jinja template` as follow: `{{ source('<source-name>', '<table-name>') }}`.

You have `order_date` stored in `orders` table. You also have sales details stored in your `order_details`.
Since you need both information (`order_date` and sales details), then you need to perform join operation.

## Grouping

Once you get the information, you can continue with aggregation.

Since you need daily total quantity and total revenue. You can the following:

```sql
WITH base AS (
    SELECT
        DATE(orders.order_date) AS order_date,
        order_details.quantity,
        order_details.price
    FROM
        {{ source('store', 'orders') }} AS orders
    JOIN
        {{ source('store', 'order_details') }} AS order_details
    ON
        orders.order_id = order_details.order_id
),

SELECT
    order_date,
    SUM(quantity) AS total_quantity,
    SUM(price) AS total_revenue
FROM
    base
GROUP BY
    order_date
```

Please take note that you can make your model refer to another model using `ref('<other-model>')`.

# Run and test your model

Once you create a model, you can then run your model

```bash
cd my_project
dbt run
dbt test
```

# Check the result

Once your model is executed, you can check the result by running the following query:

```sql
select *
from store.public_analytics.daily_sales
limit 1000;
```

# Add test

You can add test to your model by modifying your `schema.yml` into:

```yml
# this is your schema.yml

version: 2

models:
  
  - name: mrt_test
    description: ""
    tests:
      - dbt_utils.unique_combination_of_columns:
          combination_of_columns:
            - user_id
            - ticker_symbol
    columns:
      - name: (...)
```

To see what kind of test you can pefrom, you can visit dbt_utils documentation: https://github.com/dbt-labs/dbt-utils

# Installing dbt package

You can install additional dbt package by modifying `packages.yml` and invoking `dbt deps` afterwise.

```yml
packages:
  - package: dbt-labs/snowplow
    version: 0.7.0

  - git: "https://github.com/dbt-labs/dbt-utils.git"
    revision: 0.9.2

  - local: /opt/dbt/redshift
```

See dbt documentation for more information: https://docs.getdbt.com/docs/build/packages

# Task (1)

- Make a model named on `stg_order_details` containing the following info:
  - order_date
  - quantity
  - price
  - brand name
  - product name
- Base on `stg_order_details`, make another model named `fct_per_brand_daily_sales` containing per brand daily sales:
  - brand_name
  - order_date
  - total_quantity
  - total_revenue
- Add test to make sure that `fct_per_brand_daily_sales` has unique combination of `order_date` and `brand_name`

# Macro

Macro allows you to put reusable logic in one place.

For example, you want to normalize phone number by removing `+` prefix (i.e., turn `+621345678` into `621345678`).
In that case, you can create a file under `macros` folder (e.g., `macros/normalize_phone_number.sql`)

```sql
{% macro normalize_phone_number(column_name) %}
    ltrim({{ column_name }}, '+')
{% endmacro %}
```

Once you define the macro, you can call the macro in your model definition

```sql
-- models/some_model.sql
WITH base AS (
    SELECT
        *,
        {{ normalize_phone_number('customer_phone') }} AS normalized_phone
    FROM
        orders
)
SELECT * FROM base
```

# Task (2)

- Update `stg_order_details`, add the following columns:
  - customer_phone
  - normalized_customer_phone (use macro to normalize the phone number)
  - country (based on normalized_customer_phone)
    - If the phone number is started with `62`, the country should be `Indonesia`
    - If the phone number is started with `91`, the country should be `India`
- Base on `stg_order_details`, make another model named `fct_per_country_daily_sales` containing per country daily sales:
  - country
  - order_date
  - total_quantity
  - total_revenue


# Custom materialization

DBT support several materializations including:
- table
- view
- ephemeral
- incremental

Please see the documentation for more detail information https://docs.getdbt.com/docs/build/materializations

However, since we are using citus, and we have distributed table, we need to create a new materialization https://docs.getdbt.com/guides/advanced/creating-new-materializations

To do this, you can make a macro under `macros/materializations` folder. You can name the file `citus_materialization.sql`

> Note: the materialization is modified from `core/dbt/include/global_project/macros/materializations/models/table.sql`

```sql
{% materialization citus_materialization, adapter='postgres' %}

  -- NOTE: For CITUS, We need to add distribution_column parameter
  {%- set distribution_column = config.get('distribution_column', default='id') -%}

  {%- set existing_relation = load_cached_relation(this) -%}
  {%- set target_relation = this.incorporate(type='table') %}
  {%- set intermediate_relation =  make_intermediate_relation(target_relation) -%}
  -- the intermediate_relation should not already exist in the database; get_relation
  -- will return None in that case. Otherwise, we get a relation that we can drop
  -- later, before we try to use this name for the current operation
  {%- set preexisting_intermediate_relation = load_cached_relation(intermediate_relation) -%}
  /*
      See ../view/view.sql for more information about this relation.
  */
  {%- set backup_relation_type = 'table' if existing_relation is none else existing_relation.type -%}
  {%- set backup_relation = make_backup_relation(target_relation, backup_relation_type) -%}
  -- as above, the backup_relation should not already exist
  {%- set preexisting_backup_relation = load_cached_relation(backup_relation) -%}
  -- grab current tables grants config for comparision later on
  {% set grant_config = config.get('grants') %}

  -- drop the temp relations if they exist already in the database
  {{ drop_relation_if_exists(preexisting_intermediate_relation) }}
  {{ drop_relation_if_exists(preexisting_backup_relation) }}

  {{ run_hooks(pre_hooks, inside_transaction=False) }}

  -- `BEGIN` happens here:
  {{ run_hooks(pre_hooks, inside_transaction=True) }}

  -- build model
  {% call statement('main') -%}
    {{ get_create_table_as_sql(False, intermediate_relation, sql) }}
    -- NOTE: For CITUS, We need to turn the table into distributed table
    select create_distributed_table('{{ intermediate_relation }}', '{{ distribution_column }}');
  {%- endcall %}

  -- cleanup
  {% if existing_relation is not none %}
     /* Do the equivalent of rename_if_exists. 'existing_relation' could have been dropped
        since the variable was first set. */
    {% set existing_relation = load_cached_relation(existing_relation) %}
    {% if existing_relation is not none %}
        {{ adapter.rename_relation(existing_relation, backup_relation) }}
    {% endif %}
  {% endif %}

  {{ adapter.rename_relation(intermediate_relation, target_relation) }}

  {% do create_indexes(target_relation) %}

  {{ run_hooks(post_hooks, inside_transaction=True) }}

  {% set should_revoke = should_revoke(existing_relation, full_refresh_mode=True) %}
  {% do apply_grants(target_relation, grant_config, should_revoke=should_revoke) %}

  {% do persist_docs(target_relation, model) %}

  -- `COMMIT` happens here
  {{ adapter.commit() }}

  -- finally, drop the existing/backup relation after the commit
  {{ drop_relation_if_exists(backup_relation) }}

  {{ run_hooks(post_hooks, inside_transaction=False) }}

  {{ return({'relations': [target_relation]}) }}
{% endmaterialization %}
```

Then, in your model, you can define the materialization configuration:

```sql
{{
    config(
        materialized='citus_materialization',
        distribution_column='order_date'
    )
}}

WITH base AS (
    SELECT
        DATE(orders.order_date) AS order_date,
        order_details.quantity,
        order_details.price
    FROM
        {{ source('store', 'orders') }} AS orders
    JOIN
        {{ source('store', 'order_details') }} AS order_details
    ON
        orders.order_id = order_details.order_id
),
aggregated_sales AS (
    SELECT
        order_date,
        SUM(quantity) AS total_quantity,
        SUM(price) AS total_revenue
    FROM
        base
    GROUP BY
        order_date
)
SELECT
    *
FROM
    aggregated_sales
ORDER BY
    order_date
```

# Checking if the table is distributed

You can run the following query to ensure that the table is distributed:

```sql
SELECT 
  true AS is_distributed
FROM 
  pg_dist_partition 
WHERE 
  logicalrelid = 'public_analytics.daily_sales'::regclass;
```

# Generating documentation

You can generate the documentation by running:

```bash
dbt docs generate
dbt docs serve
```

You will be able to access the documentation through your browser.

