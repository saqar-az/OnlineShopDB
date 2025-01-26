-- Stored procedure to add a new product:

create or replace procedure add_product(
    n_name varchar,
    n_price numeric(10, 2),
    n_stock_count int,
    n_category_id int
)
language plpgsql as $$
begin
    insert into product ("name", price, stock_count, category_id)
    values (n_name, n_price, n_stock_count, n_category_id);

    raise notice 'product added successfully.';
end;
$$;

-- Stored procedure to add products to favorite list:

create or replace procedure add_product_to_favorite_list( 
    n_customer_id int,
    n_product_id int,
    n_quantity int
)
language plpgsql as $$
declare
    p_favorite_id int;
    available_stock int;
begin
    select stock_count into available_stock from product
    where product_id = n_product_id;

    if n_quantity > available_stock then
        raise exception 'Cannot add product to favorite list: requested quantity % exceeds available stock %', n_quantity, available_stock;
    end if;

    select favorite_id into p_favorite_id from favorite_list
    where customer_id = n_customer_id;

    if p_favorite_id is null then
        insert into favorite_list (customer_id)
        values (n_customer_id)
        returning favorite_id into p_favorite_id;
    end if;

    insert into favorite_list_items (favorite_id, product_id, quantity)
    values (p_favorite_id, n_product_id, n_quantity)
    on conflict (favorite_id, product_id)
    do update set quantity = favorite_list_items.quantity + n_quantity;
	update product set stock_count=stock_count-n_quantity
	where product.product_id=n_product_id;

    raise notice 'Product added to favorite list successfully.';
end;
$$;

-- Stored procedure to add a new user:

create or replace procedure add_new_user(  
    n_first_name varchar(100),
    n_last_name varchar(100),
    n_password varchar(30),
    n_username varchar(30),
    n_phone_numbers int
)
language plpgsql as $$
begin
    if exists (select 1 from customer where username=n_username) then
	   raise exception 'username % already exists', n_username;
	end if;   
	
    insert into customer (first_name, last_name, "password", username, phone_numbers)
    values (n_first_name, n_last_name, n_password, n_username, array[n_phone_numbers]);
end;
$$;

-- Stored procedure to add a new phone number for a customer:

create or replace procedure add_new_phonenumber( 
    n_customer_id int,
    n_phone_number int
)
language plpgsql as $$
begin
    if not exists (select 1 from customer where customer_id=n_customer_id) then
	   raise exception 'username % does not exists', n_customer_id;
	end if;   
	
    update customer set phone_numbers=array_append(phone_numbers, n_phone_number:: varchar)
    where customer_id = n_customer_id;
end;
$$;

-- Stored procedure to create a new order:

create or replace procedure create_order(  
    n_customer_id int,
    n_address_id int,
    n_product_ids int[],
    n_quantities int[]
)
language plpgsql
as $$
declare
    p_order_id int;
    product_stock int;
begin
    if array_length(n_product_ids, 1) <> array_length(n_quantities, 1) then
        raise exception 'incorrect input';
    end if;

    insert into "order" (customer_id, address_id, status)
    values (n_customer_id, n_address_id, false) 
    returning order_id into p_order_id;

    for i in 1 .. array_length(n_product_ids, 1) loop
	    select stock_count from product into product_stock
		where n_product_ids[i]=product_id;
		if n_quantities[i]>product_stock then
		  raise notice 'Can not take this item with ID: % .Requested quantity is more than available stock',n_product_ids[i];
		else
        raise notice 'ordered product ID % with quantity %', n_product_ids[i], n_quantities[i];
        insert into order_items (order_id, product_id, quantity)
        values (p_order_id, n_product_ids[i], n_quantities[i]);
		end if;

    end loop;
end;
$$;

-- Stored procedure to apply discount code:

create or replace procedure update_order_discount(orderid int, discountcode varchar) 
language plpgsql as $$
declare
    order_total numeric(10, 2) := 0;
    discount_value numeric(10, 2) := 0;
begin

    perform 1
    from discount_code
    where code = discountcode and order_id = orderid;

    if not found then
        raise exception 'not available discount code for this order';
    end if;

    perform 1
    from discount_code
    where code = discountcode and order_id = orderid and status = false;

    if found then
        raise exception 'discount code has already been used or is inactive';
    end if;

    select total_price into order_total
    from "order"
    where order_id = orderid;
    
    select percentage into discount_value
    from discount_code
    where code = discountcode and order_id = orderid and status = true;

    if discount_value is not null then
        order_total := order_total * (1 - (discount_value / 100));

        update discount_code
        set status = false
        where code = discountcode and order_id = orderid;
    end if;

    update "order"
    set total_price = order_total
    where order_id = orderid;
end;
$$;

-- Stored procedure to apply gift card:

create or replace procedure update_order_gift(orderid int, giftcode varchar)  
language plpgsql as $$
declare
    order_total numeric(10, 2) := 0;
    gift_value numeric(10, 2) := 0;
begin

    perform 1
    from gift_card
    where code = giftcode and order_id = orderid;

    if not found then
        raise exception 'not available gift card for this order';
    end if;

    perform 1
    from gift_card
    where code = giftcode and order_id = orderid and status = false;

    if found then
        raise exception 'gift card has already been used or is inactive';
    end if;

    select total_price into order_total
    from "order"
    where order_id = orderid;
    
    select "value" into gift_value
    from gift_card
    where code = giftcode and order_id = orderid and status = true;

    if gift_value is not null then
        order_total := order_total-gift_value;

        update gift_card
        set status = false
        where code = giftcode and order_id = orderid;
    end if;

    update "order"
    set total_price = order_total
    where order_id = orderid;
end;
$$;