-- Find the customer who made the most purchases in a certain time period:

select o.customer_id,count(o.customer_id) as numberoforders from "order" as o
where order_date between '2024-11-18' and '2024-11-20'
group by o.customer_id
order by numberoforders desc
limit 1

-- Find the name of the best-selling product along with its price and category:

select p.name as product_name, p.price, c.name as category_name
from product as p
join category as c on p.category_id = c.category_id
join order_items as oi on p.product_id = oi.product_id
group by p.product_id, c.name
order by sum(oi.quantity) desc
limit 1

-- Retrieve comments and rating of specific products and show which people have that product on their favorite list: 

select 
    p.name as product_name,
    r.rating,
    r.comment,
    concat(c.first_name,' ',c.last_name) as customer_name
from product as p
left join review as r on p.product_id = r.product_id
left join customer as c on r.customer_id = c.customer_id
left join favorite_list as f on f.customer_id=c.customer_id
left join favorite_list_items as fli on f.favorite_id = fli.favorite_id
where p.product_id = 19

-- Find the items of orders that customers have ordered in the past, along with the category and price of each item:

select concat(c.first_name,' ',c.last_name) as customer_name,o.order_id,p."name" as product_name,p.price,cat."name" as category_name
from customer as c,"order" as o,order_items as oi,product as p,category as cat
where c.customer_id = o.customer_id and o.order_id = oi.order_id and oi.product_id = p.product_id and p.category_id = cat.category_id
and o.order_date < now()
order by c.customer_id,o.order_id

-- Find customers who have never made a purchase:

select * from customer as c
where c.customer_id not in (select o.customer_id from "order" as o)

-- Find a list of users living in a specific city who had the highest total amount paid, along with the most expensive product they purchased per order:

select concat(c.first_name, ' ', c.last_name) as customer_name,
    sum(p.amount) as total_payments,
    max((select max(prod.price)
         from order_items as oi,product as prod
         where oi.product_id = prod.product_id and oi.order_id = o.order_id)) as most_expensive_product_price,
    max(o.order_date) as last_order_date
from
    customer as c,address as a,"order" as o,payment as p
where c.customer_id = a.customer_id and c.customer_id = o.customer_id and o.order_id = p.order_id
and a.city = 'Gongpo'
group by c.customer_id, c.first_name, c.last_name
order by total_payments desc

-- Average rating of each product with their name and category:

select p."name", c."name" as category_name, avg(r.rating) as average_rating
from product as p
join category as c on p.category_id = c.category_id
left join review as r on p.product_id = r.product_id
group by p.product_id, c.category_id

-- Products that have no review:

select p.product_id, p.name, p.price
from product as p
left join review as r on p.product_id = r.product_id
where r.review_id is null

-- Customers who have a favorite list but made no order:

select  distinct c.customer_id,concat(c.first_name,' ',c.last_name) as customer_name
from customer as c,favorite_list as f
where c.customer_id = f.customer_id and c.customer_id not in (select o.customer_id from "order" as o)

-- Customer who has the most price amount for all their orders:

select c.customer_id,concat(c.first_name,' ',c.last_name) as customer_name,sum(o.total_price) as total_amount_of_orders
from customer as c,"order" as o 
where c.customer_id = o.customer_id
group by c.customer_id
order by total_amount_of_orders desc
limit 1

-- Customers with the highest number of addresses that only made one order:

select a.customer_id,concat(c.first_name,' ',c.last_name),count(a.customer_id) as num_of_addresses from address as a,customer as c
where c.customer_id=a.customer_id and a.customer_id in (select o.customer_id from "order" as o
group by o.customer_id
having count(o.customer_id)=1
)
group by a.customer_id,c.customer_id
order by num_of_addresses desc
limit 1
