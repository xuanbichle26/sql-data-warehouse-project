/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure performs the ETL (Extract, Transform, Load) process to 
    populate the 'silver' schema tables from the 'bronze' schema.
	Actions Performed:
		- Truncates Silver tables.
		- Inserts transformed and cleansed data from Bronze into Silver tables.
		
Parameters:
    None. 
	  This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC Silver.load_silver;
===============================================================================
*/

EXEC silver.load_silver;

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
	DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;
	BEGIN TRY

		-- CLEAN AND LOAD crm_cust_info
	/* -- Check data quality of the bronze layer

	-- Check for Nulls or Duplicates in Primary key
	-- Expectation: No result
	SELECT 
	cst_id, 
	COUNT(*) 
	FROM bronze.crm_cust_info
	GROUP BY cst_id
	HAVING COUNT(*) > 1 OR cst_id IS NULL

	-- Check for unwanted space
	-- Expectation: No result
	SELECT 
		cst_firstname
	FROM bronze.crm_cust_info
	WHERE cst_firstname != TRIM(cst_firstname)

	SELECT 
		cst_lastname
	FROM bronze.crm_cust_info
	WHERE cst_lastname != TRIM(cst_lastname)
	-- Check all the columns for space

	-- Data standardization and consistency
	SELECT DISTINCT cst_gndr
	FROM bronze.crm_cust_info
	*/
		SET @batch_start_time = GETDATE();
		PRINT '=========================';
		PRINT 'Loading Silver Layer';
		PRINT '=========================';
	
		PRINT '=========================';
		PRINT 'Loading CRM Tables';
		PRINT '=========================';

		SET @start_time = GETDATE();
			PRINT '>> Truncating Table: silver.crm_cust_info';
			TRUNCATE TABLE silver.crm_cust_info;
			PRINT '>> Inserting Data into: silver.crm_cust_info';
	
			INSERT INTO silver.crm_cust_info (
				cst_id,
				cst_key,
				cst_firstname,
				cst_lastname,
				cst_marital_status,
				cst_gndr,
				cst_create_date)

			SELECT 
				cst_id,
				cst_key,
				TRIM(cst_firstname) AS cst_firstname,
				TRIM(cst_lastname) AS cst_lastname,
				CASE WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
					 WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
					 ELSE 'n/a'
				END cst_marital_status,
				CASE WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
					 WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
					 ELSE 'n/a'
				END cst_gndr,
				cst_create_date
			FROM (
				SELECT 
					*,
					ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
				FROM bronze.crm_cust_info
				WHERE cst_id IS NOT NULL
			) AS t 
			WHERE flag_last = 1
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> ------------------------';


			-- CLEAN AND LOAD crm_prd_info
			/* -- Check data quality of the bronze layer

			-- Check for Nulls or Duplicates in Primary key
			-- Expectation: No result
			SELECT 
			prd_id, 
			COUNT(*) 
			FROM bronze.crm_prd_info
			GROUP BY cst_id
			HAVING COUNT(*) > 1 OR cst_id IS NULL

			-- Check for unwanted space
			SELECT 
			prd_nm 
			FROM bronze.crm_prd_info
			WHERE prd_nm != TRIM(prd_nm)

			-- Check for NULLs or Negative Numbers
			-- Expectation: No Results
			SELECT 
			prd_cost
			FROM bronze.crm_prd_info
			WHERE prd_cost < 0 OR prd_cost IS NULL

			-- Check standardization and normalization
			SELECT DISTINCT prd_line
			FROM bronze.crm_prd_info

			-- Check for invalid Date
			SELECT *
			FROM bronze.crm_prd_info
			WHERE prd_end_dt < prd_start_dt

			-- Fill out the end date (assuming it's ok to have null end date and every records must
			have a start date - with the start date is bigger the end date previous record of the same prd
			while the time period of each record does not overlap)

			SELECT 
				prd_id,
				prd_key,
				prd_nm,
				prd_start_dt,
				prd_end_dt,
				LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) - 1 AS prd_end_dt 
			FROM bronze.crm_prd_info

			*/
		SET @start_time = GETDATE();
			PRINT '>> Truncating Table: silver.crm_prd_info';
			TRUNCATE TABLE silver.crm_prd_info;
			PRINT '>> Inserting Data into: silver.crm_prd_info';
			INSERT INTO silver.crm_prd_info (
				prd_id,
				cat_id,
				prd_key,
				prd_nm,
				prd_cost,
				prd_line,
				prd_start_dt,
				prd_end_dt 
			)
			SELECT 
				prd_id,
				REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
				SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key,
				prd_nm,
				ISNULL(prd_cost, 0) AS prd_cost,
				CASE WHEN UPPER(TRIM(prd_line)) = 'M' THEN 'Mountain'
					 WHEN UPPER(TRIM(prd_line)) = 'R' THEN 'Road'
					 WHEN UPPER(TRIM(prd_line)) = 'S' THEN 'Other Sales'
					 WHEN UPPER(TRIM(prd_line)) = 'T' THEN 'Touring'
					 ELSE 'n/a'
				END AS prd_line,
				CAST(prd_start_dt AS DATE) AS prd_start_dt,
				CAST(LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) - 1 AS DATE) AS prd_end_dt 
			FROM bronze.crm_prd_info
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> ------------------------';

			-- CLEAN AND LOAD crm_sales_details
			/* 
			-- Check if the keys in sales_details exist fully in prd_ìno

			-- Check for unmatched primary key and foreign key, expect no results

			SELECT 
			sls_ord_num,
			sls_prd_key,
			sls_cust_id,
			sls_order_dt,
			sls_ship_dt,
			sls_due_dt,
			sls_sales,
			sls_quantity,
			sls_price
			FROM bronze.crm_sales_details
			WHERE sls_cust_id NOT IN (SELECT cst_id FROM bronze.crm_cust_info)

			-- Change int to date
			-- Check negative or equal to 0 int if any
			SELECT 
			NULLIF(sls_order_dt, 0) AS sls_order_dt -- replace 0 with null
			FROM bronze.crm_sales_details
			WHERE sls_order_dt <= 0 
			OR LEN(sls_order_dt) != 8 -- check if int exceed the characters length to properly convert into date
			OR sls_order_dt > 20500101 OR sls_order_dt < 19000101 -- check if date exceed the boundary of the date range

			-- Check invalid order date
			SELECT * 
			FROM bronze.crm_sales_details
			WHERE sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt

			-- In case business rule: sales = quantity * price, sales, quantity and price are not negative, zero or nulls
			SELECT
			sls_sales,
			sls_quantity,
			sls_price
			FROM bronze.crm_sales_details
			WHERE sls_sales != sls_quantity * sls_price
			OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
			OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0
			-- Should consult the experts to handle faults => data fixed at the source systems or data fixed at the data warehouse (check for rules to make right transformation)
			-- Rules:
			-- Sales is negative, zero, null, derive it using quantity and price
			-- price is 0 or null, calculate with sales and quantity
			-- price is negative, convert to positive

			CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
				 THEN sls_quantity * ABS(sls_price)
			ELSE sls_sales
			END sls_sales,

			sls_quantity,

			CASE WHEN sls_price IS NULL OR sls_price <= 0 
				 THEN sls_sales / NULLIF(sls_quantity, 0)
			ELSE sls_price
			END sls_price

			*/ 
		SET @start_time = GETDATE();
			PRINT '>> Truncating Table: silver.crm_sales_details';
			TRUNCATE TABLE silver.crm_sales_details;
			PRINT '>> Inserting Data into: silver.crm_sales_details';
			INSERT INTO  silver.crm_sales_details (
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
			-- Clean data
			SELECT 
				sls_ord_num,
				sls_prd_key,
				sls_cust_id,
				CASE WHEN sls_order_dt <= 0 OR LEN(sls_order_dt) != 8 THEN NULL
					 ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
					 END AS sls_order_dt,
				CASE WHEN sls_ship_dt <= 0 OR LEN(sls_ship_dt) != 8 THEN NULL
					 ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
					 END AS sls_ship_dt,
				CASE WHEN sls_due_dt <= 0 OR LEN(sls_due_dt) != 8 THEN NULL
					 ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
					 END AS sls_order_dt,
				CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
					 THEN sls_quantity * ABS(sls_price)
					 ELSE sls_sales
					 END sls_sales,
				sls_quantity,
				CASE WHEN sls_price IS NULL OR sls_price <= 0 
					 THEN sls_sales / NULLIF(sls_quantity, 0) -- make sure the quantity is not 0
					 ELSE sls_price
					 END sls_price
			FROM bronze.crm_sales_details
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> ------------------------';

			-- CLEAN AND LOAD erp_cust_az12
			/*
			-- Make sure the cid have the same pattern as the cust_id
			SELECT
			cid,
			CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
				 ELSE cid
			END
			bdate,
			gen
			FROM bronze.eso_cust_az12
			WHERE cid NOT IN (SELECT cust_id FROM bronze.crm_cust_info)

			-- Identify out of range bdate
			SELECT DISTINCT 
			bdate
			FROM bronze.esp_cust_az12
			WHERE bdate < '1924-01-01' -- check for very old customers OR bdate > GETDATE()

			-- Check gender granularity -> standardization and consistency
			SELECT DISTICT gen
			FROM bronze.esp_cust_az12
			*/
		SET @start_time = GETDATE();
			PRINT '>> Truncating Table: silver.erp_cust_az12';
			TRUNCATE TABLE silver.erp_cust_az12;
			PRINT '>> Inserting Data into: silver.erp_cust_az12';
			INSERT INTO silver.erp_cust_az12 (
				cid,
				bdate,
				gen
			)
			SELECT
				CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
					 ELSE cid
				END,
				CASE WHEN bdate > GETDATE() THEN NULL
					 ELSE bdate
				END bdate,
				CASE WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
					 WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
					 ELSE 'n/a'
				END gen
			FROM bronze.erp_cust_az12
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> ------------------------';


			-- CLEAN AND LOAD erp_loc_a101
			/*
			SELECT
			cid 
			FROM bronze.erp_loc_a101;
			SELECT cst_key
			FROM bronze.crm_cust_info;

			-- Check cntry consistency
			SELECT DISTINCT cntry
			FROM bronze.erp_loc_a101
			*/
		SET @start_time = GETDATE();
			PRINT '>> Truncating Table: silver.erp_loc_a101';
			TRUNCATE TABLE silver.erp_loc_a101;
			PRINT '>> Inserting Data into: silver.erp_loc_a101';
			INSERT INTO silver.erp_loc_a101 (
				cid, 
				cntry
			)
			SELECT
				REPLACE(cid, '-', '') AS cid,
				CASE WHEN TRIM(cntry) = 'DE' THEN 'Germany'
					 WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
					 WHEN TRIM(cntry) = '' OR TRIM(cntry) IS NULL THEN 'n/a'
					 ELSE TRIM(cntry)
					 END cntry
			FROM bronze.erp_loc_a101
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> ------------------------';

			-- CLEAN AND LOAD erp_loc_a101
			/*
			SELECT
			cid, 
			cat,
			subcat,
			maintenance
			FROM bronze.erp_px_cat_g1v2

			SELECT DISTINCT cat
			FROM bronze.erp_px_cat_g1v2

			SELECT * FROM
			WHERE cat != TRIM(cat) OR subcat != TRIM(subcat) OR maintenance != TRIM(maintenance)
			*/

		SET @start_time = GETDATE();
			PRINT '>> Truncating Table: silver.erp_px_cat_g1v2';
			TRUNCATE TABLE silver.erp_px_cat_g1v2;
			PRINT '>> Inserting Data into: silver.erp_px_cat_g1v2';
			INSERT INTO silver.erp_px_cat_g1v2 (
				id,
				cat, 
				subcat,
				maintenance
			)
			SELECT
				id, 
				cat,
				subcat,
				maintenance
			FROM bronze.erp_px_cat_g1v2
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> ------------------------';
		
		SET @batch_end_time = GETDATE();
		PRINT '============================'
		PRINT 'Loading Silver Layer is Completed';
		PRINT ' - Total Load Duration: ' + CAST(DATEDIFF(second, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
		PRINT '============================'
	
	END TRY
	BEGIN CATCH
		PRINT '========================================='
		PRINT 'ERROR OCCURED DURING LOADING SILVER LAYER'
		PRINT 'Error Message' + ERROR_MESSAGE();
		PRINT 'Error Message' + CAST(ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Error Message' + CAST(ERROR_STATE() AS NVARCHAR);
		PRINT '========================================='
	END CATCH
END
