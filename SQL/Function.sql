-- Function that calculates the total sales of a specific product in a specified time period:

create or replace function total_sales(desired_product_id int, start_date TIMESTAMP, end_date TIMESTAMP)  
returns numeric(10, 2) 
as $$
declare
    total_sales numeric(10, 2) := 0;
begin
    select COALESCE(sum(oi.quantity * p.price), 0) into total_sales
    from order_items as oi
    join "order" as o on oi.order_id = o.order_id
    join product as p on oi.product_id = p.product_id
    where p.product_id = desired_product_id and o.order_date between start_date and end_date;

    return total_sales;
end;
$$ language plpgsql;

-- Function to display the total monthly sales and the number of products sold for each category in a particular month:

create or replace function monthly_sales_category(year int, month int)  
returns table(category_name varchar, total_sales numeric(10,2), products_sold int) as $$
begin
    return query
    select c.name as category_name,
           COALESCE(sum(oi.quantity * p.price), 0) as total_sales,
           COALESCE(sum(oi.quantity), 0)::int as products_sold
    from "order" as o
    join order_items as oi on o.order_id = oi.order_id
    join product as p on oi.product_id = p.product_id
    join category as c on p.category_id = c.category_id
    where extract(year from o.order_date) = year
      and extract(month from o.order_date) = month
    group by c.category_id;
end;
$$ language plpgsql;

-- Function to get products avg rating:

create or replace function average_product_rating(productid int)  
returns numeric(10, 2) as $$
declare
    average_rating numeric(10, 2);
begin
    select avg(r.rating) into average_rating
    from review as r
    join product as p on r.product_id = p.product_id
    where p.product_id = productid;

    return COALESCE(average_rating, 0);
end;
$$ language plpgsql;