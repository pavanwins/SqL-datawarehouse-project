INSERT INTO silver.crm_cust_info (
			cst_id, 
			cst_key, 
			cst_firstname, 
			cst_lastname, 
			cst_marital_status, 
			cst_gndr,
			cst_create_date
		)
		SELECT
			cst_id,
			cst_key,
			TRIM(cst_firstname) AS cst_firstname,
			TRIM(cst_lastname) AS cst_lastname,
			CASE 
				WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
				WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
				ELSE 'n/a'
			END AS cst_marital_status, -- Normalize marital status values to readable format
			CASE 
				WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
				WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
				ELSE 'n/a'
			END AS cst_gndr, -- Normalize gender values to readable format
			cst_create_date
		FROM (
			SELECT
				*,
				ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
			FROM bronze.crm_cust_info
			WHERE cst_id IS NOT NULL
		) t
		WHERE flag_last = 1;










insert into silver.crm_prd_info (
    prd_id          ,
    cat_id         ,
    prd_key        ,
    prd_nm          ,
    prd_cost        ,
    prd_line        ,
    prd_start_dt    ,
    prd_end_dt       
)
select 
prd_id,
Replace(SUBSTRING(prd_key,1,5),'-','_') as cat_id,
SUBSTRING(prd_key,7,len(prd_key)) as prd_key,
prd_nm,
ISNULL(prd_cost,0) as prd_cost,
CASE
 WHEN UPPER(TRIM(prd_line)) = 'M' THEN 'Mountain'
 WHEN UPPER(TRIM(prd_line)) = 'R' THEN 'Road'
 WHEN UPPER(TRIM(prd_line)) = 'S' THEN 'Other sales'
 WHEN UPPER(TRIM(prd_line)) = 'T' THEN 'Touring'
 else 'n/a'
 end as prd_line,
 CAST(prd_start_dt as DATE) as prd_start_dt,
 cast(lead(prd_start_dt) over(partition by prd_key order by prd_start_dt) - 1 as DATE) as prd_end_dt
from bronze.crm_prd_info;






-- fIXING SALES DETAILS 




CREATE TABLE silver.crm_sales_details (
    sls_ord_num     NVARCHAR(50),
    sls_prd_key     NVARCHAR(50),
    sls_cust_id     INT,
    sls_order_dt    DATE,
    sls_ship_dt     DATE,
    sls_due_dt      DATE,
    sls_sales       INT,
    sls_quantity    INT,
    sls_price       INT,
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);

INSERT INTO silver.crm_sales_details (
			sls_ord_num,
			sls_prd_key,
			sls_cust_id,
			sls_order_dt,
			sls_ship_dt,
			sls_due_dt,
			sls_sales,
			sls_quantity,
			sls_price
		)
select 
sls_ord_num,
sls_prd_key,
sls_cust_id,
case 
 when sls_order_dt = 0 or len(sls_order_dt) != 8 then NULL
 else cast(CAST(SLS_order_dt as varchar) as date) 
 end as sls_order_dt,
case 
 when sls_ship_dt = 0 or len(sls_ship_dt) != 8 then NULL
 else cast(CAST(sls_ship_dt as varchar) as date) 
 end as sls_ship_dt,
case
 when sls_due_dt = 0 or len(sls_due_dt) != 8 then NULL
 else cast(CAST(sls_due_dt as varchar) as date) 
 end as sls_due_dt,
 CASE
  WHEN SLS_SALES IS NULL OR SLS_SALES <= 0 or SLS_SALES != sls_quantity * ABS(sls_price)
  then sls_quantity * ABS(sls_price)
  else SLS_SALES
  end as sls_sales,
 CASE
  WHEN SLS_price IS NULL OR SLS_price <= 0 
  then sls_sales / NULLIF(sls_quantity,0)
  else SLS_price
  end as SLS_price,
  sls_quantity
from bronze.crm_sales_details;








--   FIXING CUST_AZ12



insert into silver.erp_cust_az12(
 cid,
 bdate,
 gen)
SELECT 
case 
when cid LIKE 'NAS%' then SUBSTRING(Cid,4, len(Cid))
else cid
end as cid,
case 
 when bdate > getDate() then NULL
 else bdate
 end as bdate,
 case 
  when upper(trim(gen)) in ('F','FEMALE') THEN 'Female'
  when upper(trim(gen)) in ('M','MALE') THEN 'Male'
  else 'n/a'
  end as gen
FROM bronze.erp_cust_az12;




-- FIXING LOC_A101




insert into silver.erp_loc_a101(
cid,
cntry
)
SELECT 
replace(cid,'-','') as cid,
CASE 
 WHEN trim(cntry) = 'DE' then 'Germany'
 when trim(cntry) in ('US' ,'USA') then 'United States'
 when trim(cntry) = '' or cntry is null then 'n/a'
 else trim(cntry)
 end as cntry
FROM bronze.erp_loc_a101;




-- Category table


insert into silver.erp_px_cat_g1v2(
id,
cat,
subcat,
maintenance)
select * from bronze.erp_px_cat_g1v2
