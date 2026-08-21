CREATE SCHEMA IF NOT EXISTS dw;

CREATE TABLE IF NOT EXISTS dw.dim_customer
(
    customer_sk integer NOT NULL,
    customer_id integer NOT NULL,
    customer_name character varying(50) NOT NULL,
    customer_type character varying(50),
    CONSTRAINT dim_customer_pkey PRIMARY KEY (customer_sk)
);

CREATE TABLE IF NOT EXISTS dw.dim_location
(
    location_sk integer NOT NULL,
    location_id integer NOT NULL,
    country character varying(50) NOT NULL,
    region character varying(50) NOT NULL,
    state character varying(50) NOT NULL,
    city character varying(50) NOT NULL,
    CONSTRAINT dim_location_pkey PRIMARY KEY (location_sk)
);

CREATE TABLE IF NOT EXISTS dw.dim_product
(
    product_sk integer NOT NULL,
    product_id integer NOT NULL,
    product_name character varying(50) NOT NULL,
    category character varying(50) NOT NULL,
    subcategory character varying(50) NOT NULL,
    CONSTRAINT dim_product_pkey PRIMARY KEY (product_sk)
);

CREATE TABLE IF NOT EXISTS dw.dim_time
(
    time_sk integer NOT NULL,
    full_date date,
    year integer NOT NULL,
    month integer NOT NULL,
    day integer NOT NULL,
    CONSTRAINT dim_time_pkey PRIMARY KEY (time_sk)
);

CREATE TABLE IF NOT EXISTS dw.fact_sales
(
    product_sk integer NOT NULL,
    customer_sk integer NOT NULL,
    location_sk integer NOT NULL,
    time_sk integer NOT NULL,
    quantity integer NOT NULL,
    unit_price numeric(10,2) NOT NULL,
    product_cost numeric(10,2) NOT NULL,
    sales_revenue numeric(10,2) NOT NULL,
    CONSTRAINT fact_sales_pkey PRIMARY KEY (product_sk, customer_sk, location_sk, time_sk),
    CONSTRAINT fact_sales_customer_sk_fkey FOREIGN KEY (customer_sk) REFERENCES dw.dim_customer (customer_sk),
    CONSTRAINT fact_sales_location_sk_fkey FOREIGN KEY (location_sk) REFERENCES dw.dim_location (location_sk),
    CONSTRAINT fact_sales_product_sk_fkey FOREIGN KEY (product_sk) REFERENCES dw.dim_product (product_sk),
    CONSTRAINT fact_sales_time_sk_fkey FOREIGN KEY (time_sk) REFERENCES dw.dim_time (time_sk)
);

-- Replace <YOUR_BUCKET_NAME> and <YOUR_AWS_ACCOUNT_ID> with your own values before running.
COPY dw.dim_customer
FROM 's3://<YOUR_BUCKET_NAME>/data/dim_customer.csv'
IAM_ROLE 'arn:aws:iam::<YOUR_AWS_ACCOUNT_ID>:role/RedshiftS3AccessRole'
CSV;

COPY dw.dim_location
FROM 's3://<YOUR_BUCKET_NAME>/data/dim_location.csv'
IAM_ROLE 'arn:aws:iam::<YOUR_AWS_ACCOUNT_ID>:role/RedshiftS3AccessRole'
CSV;

COPY dw.dim_product
FROM 's3://<YOUR_BUCKET_NAME>/data/dim_product.csv'
IAM_ROLE 'arn:aws:iam::<YOUR_AWS_ACCOUNT_ID>:role/RedshiftS3AccessRole'
CSV;

COPY dw.dim_time
FROM 's3://<YOUR_BUCKET_NAME>/data/dim_time.csv'
IAM_ROLE 'arn:aws:iam::<YOUR_AWS_ACCOUNT_ID>:role/RedshiftS3AccessRole'
CSV;

COPY dw.fact_sales
FROM 's3://<YOUR_BUCKET_NAME>/data/fact_sales.csv'
IAM_ROLE 'arn:aws:iam::<YOUR_AWS_ACCOUNT_ID>:role/RedshiftS3AccessRole'
CSV;
