-- Materialized View that stores a list of users along with their recorded ratings for products and the average rating of the products:

create materialized view reviews as 
select c.customer_id,c.first_name,c.last_name,
    count(r.review_id) as total_reviews,
    coalesce(avg(r.rating), 0) as average_rating
from customer as c
left join review as r on c.customer_id = r.customer_id
group by c.customer_id;

-- Materialized View that displays product information along with the number of times they have been purchased:

create materialized view product_summary as 
select 
    p.product_id,p.name as product_name,p.price,p.stock_count,
    COALESCE(sum(oi.quantity), 0) as times_purchased
from product as p
left join order_items as oi on p.product_id = oi.product_id
group by p.product_id, p.name, p.price, p.stock_count;

-- Materialized View that displays discount summary:

create materialized view discount_summary as  
select 
    o.order_id,
    d.code as discount_code,
    d.percentage as discount_percentage,
    o.total_price
from "order" as o
left join discount_code as d on o.order_id = d.order_id
where d.status = true;

-- Materialized View that displays sales by category summary:

create materialized view sales_by_category as  
select c.category_id,c.name,sum(oi.quantity) as total_quantity_sold,sum(oi.quantity * p.price) as total_sales
from category as c
join product as p on c.category_id = p.category_id
join order_items oi on p.product_id = oi.product_id
join "order" o on oi.order_id = o.order_id
group by c.category_id, c.name;

-- Materialized View that displays the monthly sales report for each product category by number of products sold and total revenue:

create materialized view monthly_report as  
select c.name as category_name,
    DATE_TRUNC('month', o.order_date) as sales_month,
    sum(oi.quantity) as total_products_sold,
    sum(oi.quantity * p.price) as total_revenue
from "order" as o
join order_items as oi on o.order_id = oi.order_id
join product as p on oi.product_id = p.product_id
join category as c on p.category_id = c.category_id
group by c.name, sales_month;
