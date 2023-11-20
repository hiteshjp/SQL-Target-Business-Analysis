-- Get the time range between which the orders were placed.
select 
min(order_purchase_timestamp) as first_date_of_purchase,
max(order_purchase_timestamp) as last_date_of_purchase
from `ecommerce.orders`

-- Count the Cities & States of customers who ordered during the given period.

SELECT 
  COUNT(DISTINCT c.customer_city) AS cities,
  COUNT(DISTINCT c.customer_state) AS states
FROM `ecommerce.customers` c
JOIN `ecommerce.orders` o ON c.customer_id = o.customer_id

-- Is there a growing trend in the no. of orders placed over the past years?
--Number of orders  years each year 

select * , 
round((order_count - previous_year_order_count)*100/previous_year_order_count , 2 ) as percentage_change
from 
(select* , 
lag(order_count) over(order by order_count) as previous_year_order_count
from (
select 
extract (year from order_purchase_timestamp) as year , 
count(*) as order_count , 
from `ecommerce.orders`
group by year 
order by year )
)
order by year

-- Can we see some kind of monthly seasonality in terms of the no. of orders being placed?
select 
format_timestamp ('%B' , order_purchase_timestamp) as month , 
count(*) as monthly_order_count
from `ecommerce.orders`
group by month 
order by monthly_order_count desc

-- During what time of the day, do the Brazilian customers mostly place their orders? (Dawn, Morning, Afternoon or Night)
0-6 hrs : Dawn
7-12 hrs : Mornings
13-18 hrs : Afternoon
19-23 hrs : Night

select
case 
when a.hour between 0 and 6 then 'Dawn'  
when a.hour between 7 and 12 then 'Mornings' 
when a.hour between 13 and 18 then 'Afternoon' 
else 'Night' end as time_of_day , 
sum(a.hourly_count) as total_count
from
(
select 
extract (hour from order_purchase_timestamp) as hour , 
count(*) as hourly_count
from `ecommerce.orders`
group by hour 
order by hourly_count desc
) a 
group by time_of_day
order by total_count desc

-- Get the month on month no. of orders placed in each state.

with monthly_order_counts as (
select 
extract (year from order_purchase_timestamp) as order_year , 
extract (month from order_purchase_timestamp) as order_month , 
count(*) as monthly_order_count , 
from `ecommerce.orders`
group by order_year , order_month
order by order_year , order_month
) 

select *,
case 
when monthly_order_count > previous_month_order_count then concat('Increased by', ' ' , monthly_order_count - previous_month_order_count) 
when monthly_order_count < previous_month_order_count then concat('Decreased by',' ', previous_month_order_count - monthly_order_count) 
else null
end as change_from_previous_month
from (
select *, 
lag(monthly_order_count) over(order by order_year , order_month) as previous_month_order_count ,
from monthly_order_counts 
order by order_year , order_month )

-- How are the customers distributed across all the states?

select
customer_state , 
count(*) as customer_count
from `ecommerce.customers`
group by customer_state
order by customer_count desc

-- Get the % increase in the cost of orders from year 2017 to 2018 (include months between Jan to Aug only). 
select* , 
round ((cost_of_orders - lag(cost_of_orders) over(order by year) )*100/cost_of_orders , 2 ) as percentage_increase
from
(select 
a.year ,
round(sum(a.payment_value) , 2 ) cost_of_orders 
from 
(select 
o.order_id , o.order_purchase_timestamp , p.payment_value ,
extract (year from o.order_purchase_timestamp) as year , 
extract (month from o.order_purchase_timestamp) as month 
from `ecommerce.payments` p 
join `ecommerce.orders` o 
on p.order_id = o.order_id
) a 
where a.month between 1 and 8
group by a.year 
order by a.year
) b
order by year

-- Calculate the Total & Average value of order price for each state.
select
c.customer_state , 
round(sum(oi.price) , 2 ) as total_value_of_order_price , 
round(avg(oi.price), 2) as average_value_of_order_price
from `ecommerce.order_items` oi
join `ecommerce.orders` o on o.order_id = oi.order_id 
join `ecommerce.customers` c on c.customer_id = o.customer_id
group by c.customer_state
order by total_value_of_order_price desc

-- Calculate the Total & Average value of order freight for each state.
select
c.customer_state ,
round(sum(oi.freight_value) , 2 ) as total_value_of_order_freight , 
round(avg(oi.freight_value), 2 ) as average_value_of_order_freight
from `ecommerce.order_items` oi 
join `ecommerce.orders` o on oi.order_id = o.order_id 
join `ecommerce.customers` c on o.customer_id = c.customer_id 
group by c.customer_state


-- Find the no. of days taken to deliver each order from the order’s purchase date as delivery time.
-- Also, calculate the difference (in days) between the estimated & actual delivery date of an order.
-- time_to_deliver = order_delivered_customer_date - order_purchase_timestamp
-- diff_estimated_delivery = order_estimated_delivery_date - order_delivered_customer_date

SELECT 
order_id,
TIMESTAMP_DIFF(order_delivered_customer_date, order_purchase_timestamp, DAY) AS time_to_deliver,
CASE 
WHEN TIMESTAMP_DIFF(order_estimated_delivery_date, order_delivered_customer_date, DAY) < 0 THEN CONCAT('Late by', ' ', TIMESTAMP_DIFF(order_delivered_customer_date, order_estimated_delivery_date, DAY), ' days')
WHEN TIMESTAMP_DIFF(order_estimated_delivery_date, order_delivered_customer_date, DAY) = 0 THEN 'On time'
ELSE CONCAT('Early by', ' ', TIMESTAMP_DIFF(order_estimated_delivery_date, order_delivered_customer_date, DAY), ' days')
END AS diff_estimated_delivery
FROM `ecommerce.orders`;

-- Find out the top 5 states with the highest & lowest average delivery time.
WITH AvgDeliveryTimes AS (
SELECT
a.customer_state,
AVG(a.time_to_deliver) AS avg_delivery_time
FROM (
SELECT
order_id,
          customer_state,
            TIMESTAMP_DIFF(order_delivered_customer_date, order_purchase_timestamp, DAY) AS time_to_deliver
        FROM `ecommerce.orders` o
        JOIN `ecommerce.customers` c ON o.customer_id = c.customer_id
    ) a
    GROUP BY a.customer_state
)

SELECT
    customer_state,
    avg_delivery_time
FROM (
    SELECT
        customer_state,
        avg_delivery_time,
        RANK() OVER (ORDER BY avg_delivery_time DESC) AS high_rank,
        RANK() OVER (ORDER BY avg_delivery_time ASC) AS low_rank
    FROM AvgDeliveryTimes
) ranked_data
WHERE high_rank <= 5 OR low_rank <= 5;


WITH AvgDeliveryTimes AS (
SELECT
a.customer_state,
AVG(a.time_to_deliver) AS avg_delivery_time
FROM (
SELECT
order_id,
customer_state,
TIMESTAMP_DIFF(order_delivered_customer_date, order_purchase_timestamp, DAY) AS time_to_deliver
FROM `ecommerce.orders` o
JOIN `ecommerce.customers` c ON o.customer_id = c.customer_id
) a
GROUP BY a.customer_state
)
SELECT
customer_state,
avg_delivery_time,
'Highest' AS rank
FROM (
SELECT
customer_state,
avg_delivery_time,
RANK() OVER (ORDER BY avg_delivery_time DESC) AS high_rank,
RANK() OVER (ORDER BY avg_delivery_time ASC) AS low_rank
FROM AvgDeliveryTimes
) ranked_data
WHERE high_rank <= 5

UNION ALL

SELECT
customer_state,
avg_delivery_time,
'Lowest' AS rank
FROM (
SELECT
customer_state,
avg_delivery_time,
RANK() OVER (ORDER BY avg_delivery_time ASC) AS low_rank
FROM AvgDeliveryTimes
) ranked_data
WHERE low_rank <= 5
ORDER BY avg_delivery_time DESC;

-- Top 5 states with the highest average freight value.

select 
customer_state,total_freight_value,avg_freight_value,
'Highest' as rank
from (
select
c.customer_state,
round(sum(oi.freight_value), 2) as total_freight_value,
round(sum(oi.freight_value) / count(*), 2) as avg_freight_value
from `ecommerce.order_items` oi
join `ecommerce.orders` o on oi.order_id = o.order_id
join `ecommerce.customers` c on o.customer_id = c.customer_id
group by c.customer_state
order by avg_freight_value desc
limit 5
)
union all
select customer_state, total_freight_value, avg_freight_value,'Lowest' as rank
from (
select c.customer_state, 
round(sum(oi.freight_value), 2) as total_freight_value,
round(sum(oi.freight_value) / count(*), 2) as avg_freight_value
from `ecommerce.order_items` oi
join `ecommerce.orders` o on oi.order_id = o.order_id
join `ecommerce.customers` c on o.customer_id = c.customer_id
group by c.customer_state
order by avg_freight_value asc
limit 5
)

-- Find the month on month no. of orders placed using different payment types.

with monthlyordercounts as (
select
extract(YEAR from order_purchase_timestamp) as order_year,extract(MONTH from order_purchase_timestamp) as order_month,
p.payment_type,
count(*) as number_of_orders 
from `ecommerce.payments` p
join `ecommerce.orders` o ON p.order_id = o.order_id
group by 1, 2, 3
)

select order_year, order_month,
sum(case when payment_type = 'credit Card' then number_of_orders else 0 end) as credit_card_orders,
sum(case when payment_type = 'debit Card' then number_of_orders else 0 end) as debit_card_orders,
sum(case when payment_type = 'UPI' then number_of_orders else 0 end) as UPI
sum(case when payment_type = 'voucher' then number_of_orders else 0 end) as voucher,
from monthlyordercounts
group by order_year, order_month
group by order_year, order_month;

Find the no. of orders placed on the basis of the payment installments that have been paid.
select
p.payment_installments as num_installments_paid ,
count(distinct o.order_id) as num_orders
from `ecommerce.orders` o
join `ecommerce.payments` p on o.order_id = p.order_id
where p.payment_sequential = 1 
group by p.payment_installments
order by  num_orders desc


