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
