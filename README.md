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

# Try it yourself

- Make a model based on order_details containing the following info:
  - order date
  - quantity
  - price
  - brand name
  - product name
- Base on that model, make another model named `per_brand_daily_sales`


