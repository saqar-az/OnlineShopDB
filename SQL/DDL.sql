create table customer (
    customer_id serial primary key,
    first_name varchar(100) not null,
    last_name varchar(100) not null,
    "password" varchar(100) not null,
    username varchar(30) unique not null,
    wallet_balance numeric(10, 2) default 0.00,
    phone_numbers text[]
);

create table address (
    address_id serial primary key,
    street_name varchar(50) not null,
    street_number varchar(30) not null,
    country varchar(30) not null,
    city varchar(30) not null,
    postal_code varchar(30) not null,
    province varchar(30) not null,
    customer_id int not null,
    foreign key (customer_id) references customer(customer_id) on delete cascade
);

create table category (
    category_id serial primary key,
    "name" varchar(50) not null
);

create table product (
    product_id serial primary key,
    "name" varchar(100) not null,
    price numeric(10, 2) not null,
    stock_count int check (stock_count>-1),
    category_id int,
    rating numeric(5, 2) default 0.00,
    foreign key (category_id) references category(category_id) on delete cascade
);

create table review (
    review_id serial primary key,
    rating int check (rating >= 1 and rating <= 5),
    "comment" text,
    customer_id int not null,
    product_id int not null,
    foreign key (customer_id) references customer(customer_id) on delete cascade,
    foreign key (product_id) references product(product_id) on delete cascade,
    check (comment is not null or rating is not null)
);

create table favorite_list (
    favorite_id serial primary key,
    total_price numeric(10, 2) default 0.00,
    create_date timestamp not null default current_timestamp,
    customer_id int not null unique,
    foreign key (customer_id) references customer(customer_id) on delete cascade
);

create table favorite_list_items (
    favorite_id int not null,
    product_id int not null,
    quantity int not null,
    primary key (favorite_id, product_id),
    foreign key (favorite_id) references favorite_list(favorite_id) on delete cascade,
    foreign key (product_id) references product(product_id) on delete cascade
);

create table "order" (
    order_id serial primary key,
    order_date timestamp not null default current_timestamp,
    total_price numeric(10, 2) default 0.00,
    status boolean not null,
    customer_id int not null,
    address_id int not null,
    foreign key (customer_id) references customer(customer_id) on delete cascade,
    foreign key (address_id) references address(address_id) on delete cascade
);

create table payment (
    payment_id serial primary key,
    amount numeric(10, 2) not null,
    "method" varchar(30) not null,
    payment_date timestamp not null default current_timestamp,
    order_id int not null,
    customer_id int not null,
    foreign key (order_id) references "order"(order_id) on delete cascade,
    foreign key (customer_id) references customer(customer_id) on delete cascade
);

create table order_items (
    quantity int not null,
    order_id int not null,
    product_id int not null,
    primary key (order_id, product_id),
    foreign key (order_id) references "order"(order_id) on delete cascade,
    foreign key (product_id) references product(product_id) on delete cascade
);

create table discount_code (
    discount_id serial primary key,
    code varchar(30) unique not null,
    percentage numeric(5, 2) not null check (percentage >= 0 and percentage <= 100),
    status boolean not null,
    order_id int not null,
    foreign key (order_id) references "order"(order_id) on delete cascade
);

create table gift_card (
    gift_id serial primary key,
    "value" numeric(10, 2) not null,
    code varchar(30) unique not null,
    status boolean not null,
    order_id int not null,
    foreign key (order_id) references "order"(order_id) on delete cascade
);

create table order_history_log (
    log_id serial primary key,
    customer_id int not null,
    order_id int not null,
    order_details jsonb not null,
    logged_at timestamp not null default current_timestamp,
    foreign key (customer_id) references customer(customer_id) on delete cascade,
    foreign key (order_id) references "order"(order_id) on delete cascade
);

