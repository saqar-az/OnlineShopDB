-- Trigger to calculate favorite list's total price:

create or replace function update_favorite_list_total_price() 
returns trigger as $$
declare
    fave_total numeric(10, 2) := 0;
begin
    select sum(f.quantity * p.price) into fave_total
    from favorite_list_items as f
    join product as p on f.product_id = p.product_id
    where f.favorite_id = new.favorite_id; 

    update favorite_list
    set total_price = fave_total
    where favorite_id = new.favorite_id; 

    return new;
end;
$$ language plpgsql;
create trigger update_favorite_list_total_price_trigger
after insert or update on favorite_list_items
for each row execute function update_favorite_list_total_price();

-- Trigger to calculate the favorite list's total price after deletion of items:

create or replace function update_favorite_list_total_price_after_delete() 
returns trigger as $$
declare
    fave_total numeric(10, 2) := 0;
begin
    select coalesce (sum(f.quantity * p.price), 0) into fave_total
    from favorite_list_items as f
    join product as p on f.product_id = p.product_id
    where f.favorite_id = OLD.favorite_id; 

    update favorite_list
    set total_price = fave_total
    where favorite_id = OLD.favorite_id; 

    return OLD;
end;
$$ language plpgsql;
create trigger update_favorite_list_total_price_after_delete_trigger
after delete on favorite_list_items
for each row execute function update_favorite_list_total_price_after_delete();

-- Trigger to calculate order's total price:

create or replace function update_order_total_price() 
returns trigger as  $$
declare
    order_total numeric(10, 2) := 0;
    discount_value numeric(10, 2) := 0;
    gift_card_value numeric(10, 2) := 0;
begin

    select sum(i.quantity * p.price) into order_total
    from order_items as i
    join product as p on i.product_id = p.product_id
    where i.order_id = NEW.order_id;

    update "order"
    set total_price = order_total
    where order_id = NEW.order_id;

    return new;
end;
$$ language plpgsql;

create trigger update_order_total_price
after insert or update on order_items
for each row execute function update_order_total_price();

-- Trigger to check the address of the order:

create or replace function check_customer_address() 
returns trigger as $$
declare
    addresscount int;
begin
    select count(*) into addresscount 
    from address 
    where customer_id = new.customer_id and address_id = new.address_id;

    if addresscount = 0 then
        raise exception 'the customer must have at least one address before placing an order.';
    end if;

    return new;
end;
$$ language plpgsql;

create trigger check_customer_address_before_order
before insert on "order"
for each row execute function check_customer_address();

-- Trigger to update order status and wallet balance after payment:

create or replace function update_order_status_to_paid() 
returns trigger as $$
declare
    total_order_amount numeric(10, 2);
    total_payment_amount numeric(10, 2);
    excess_payment numeric(10, 2);
begin
    select total_price into total_order_amount from "order" where order_id = new.order_id;
    select coalesce(sum(amount), 0) into total_payment_amount from payment where order_id = new.order_id;
    select wallet_balance into excess_payment from customer where customer_id = new.customer_id;

    total_payment_amount := total_payment_amount + excess_payment;

    if total_payment_amount >= total_order_amount then
        update "order" set status = true where order_id = new.order_id;
        raise notice 'order % has been marked as paid', new.order_id;
        excess_payment := total_payment_amount - total_order_amount;

        if excess_payment > 0 then
            update customer set wallet_balance = excess_payment where customer_id = new.customer_id;
            raise notice 'excess payment of % will be carried over for future payments of customer %', excess_payment, new.customer_id;
        end if;
    else
	    update payment set amount = total_payment_amount where payment_id = new.payment_id;
		update customer set wallet_balance = 0 where customer_id = new.customer_id;
        raise notice 'payment for order % is not sufficient. current payment: %, required: %', new.order_id, total_payment_amount, total_order_amount;
        return null;
    end if;
    return new;
end;
$$ language plpgsql;

create trigger update_order_status_to_paid_trigger
after insert on payment
for each row execute function update_order_status_to_paid();

-- Trigger to update product's rating:

create or replace function update_product_rating() 
returns trigger as $$
declare
    average_rating numeric(5, 2);
begin
    select avg(rating) into average_rating from review where product_id = NEW.product_id;
    update product set rating = average_rating where product_id = NEW.product_id;
    return new;
end;
$$ language plpgsql;

create trigger trigger_update_product_rating
after insert or update on review
for each row execute function update_product_rating();

-- Trigger to update product's rating after delete:

create or replace function update_product_rating_after_delete() 
returns trigger as $$
declare
    average_rating numeric(5, 2);
begin
    select avg(rating) into average_rating from review where product_id = old.product_id;
    update product set rating = average_rating where product_id = old.product_id;

    return old;
end;
$$ language plpgsql;

create trigger trigger_update_product_rating_after_delete
after delete on review
for each row execute function update_product_rating_after_delete();

-- Trigger to update product's quantity:

create or replace function product_quantity() 
returns trigger as $$
declare
    available_stock int;
begin
    select stock_count into available_stock from product where product_id = NEW.product_id;
    IF NEW.quantity > available_stock then
        raise notice 'Cannot place order: Requested quantity is more than available stock';
        return null;
    else
        update product set stock_count = stock_count - NEW.quantity where product_id = NEW.product_id;
    end if;

    return new;
end;
$$ language plpgsql;

create trigger trigger_product_quantity
before insert on order_items
for each row execute function product_quantity();

-- Trigger to notify a new review for a product:

create or replace function notify_new_review() 
returns trigger as $$
begin 
    if new.rating is null and new."comment" is not null then
	raise notice 'new review added for product % by customer :% comment :% ', new.product_id, new.customer_id, new."comment";
    elseif new."comment" is null then
    raise notice 'new review added for product % by customer :% rating :% ', new.product_id, new.customer_id, new.rating;
    else 
	raise notice 'new review added for product % by customer :% rating :% comment :% ', new.product_id, new.customer_id, new.rating , new."comment";
	end if;
	return new;
end;
$$ language plpgsql;

create trigger notify_new_review_trigger
after insert on review
for each row execute function notify_new_review();

-- Trigger to update history log:

create or replace function log_order_history()
returns trigger as $$
declare
    order_items_data jsonb;
begin
    select jsonb_agg(jsonb_build_object(
        'product_id', oi.product_id,
        'quantity', oi.quantity,
        'price', p.price
    ))
    into order_items_data
    from order_items as oi
    join product as p on oi.product_id = p.product_id
    where oi.order_id = NEW.order_id;

    insert into order_history_log (customer_id, order_id, order_details)
    values (NEW.customer_id, NEW.order_id, jsonb_build_object(
        'order_date', NEW.order_date,
        'total_price', NEW.total_price,
        'status', NEW.status,
        'items', order_items_data
    ));

    return new;
end;
$$ language plpgsql;

create trigger order_status_trigger
after update of status on "order"
for each row
when (NEW.status = true)
execute function log_order_history();

