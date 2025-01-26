-- View that displays the payment details (payment date and total amount) along with the location (city and country) of the orders:

create or replace view payment_details as  
select p.payment_date,p.amount as total_amount,a.city,a.country
from payment as p
join "order" as o on p.order_id = o.order_id
join address as a on o.address_id = a.address_id;

-- View that displays users along with their list of favorites (product names and prices):

create or replace view users_favorites as 
select c.customer_id,concat(c.first_name,' ',c.last_name) as full_name,p.name as product_name,p.price
from customer as c
join favorite_list as f on c.customer_id=f.customer_id
join favorite_list_items as fi on fi.favorite_id = f.favorite_id
join product as p on fi.product_id = p.product_id;

-- View that displays all orders placed by the users:
create or replace view user_orders as 
select c.customer_id,o.order_id,o.total_price
from "order" as o
join customer as c on o.customer_id = c.customer_id;

-- View that displays popular products based on the number of orders:

create or replace view popular_products as 
select p.name as product_name,sum(oi.quantity) as total_quantity_sold
from order_items as oi
join product as p on oi.product_id = p.product_id
group by p.product_id, p.name
order by total_quantity_sold desc;

-- View that displays total amount paid for each customer:

create or replace view total_spending_per_user as 
select c.customer_id,c.first_name,c.last_name,sum(p.amount) as total_spent
from customer as c
join payment as p on c.customer_id = p.customer_id
group by c.customer_id, c.first_name, c.last_name;