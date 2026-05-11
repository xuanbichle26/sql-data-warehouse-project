/*
===============================================================================
Quality Checks
===============================================================================
Script Purpose:
    This script performs various quality checks for data consistency, accuracy, 
    and standardization across the 'silver' layer. It includes checks for:
    - Null or duplicate primary keys.
    - Unwanted spaces in string fields.
    - Data standardization and consistency.
    - Invalid date ranges and orders.
    - Data consistency between related fields.

Usage Notes:
    - Run these checks after data loading Silver Layer.
    - Investigate and resolve any discrepancies found during the checks.
===============================================================================
*/


-- CLEAN AND LOAD crm_cust_info
	-- Check for Nulls or Duplicates in Primary key
	-- Expectation: No result
	SELECT 
	cst_id, 
	COUNT(*) 
	FROM silver.crm_cust_info
	GROUP BY cst_id
	HAVING COUNT(*) > 1 OR cst_id IS NULL

	-- Check for unwanted space
	-- Expectation: No result
	SELECT 
		cst_firstname
	FROM silver.crm_cust_info
	WHERE cst_firstname != TRIM(cst_firstname)

	SELECT 
		cst_lastname
	FROM silver.crm_cust_info
	WHERE cst_lastname != TRIM(cst_lastname)
	-- Check all the columns for space

	-- Data standardization and consistency
	SELECT DISTINCT cst_gndr
	FROM silver.crm_cust_info


			-- CLEAN AND LOAD crm_prd_info
-- Check data quality of the bronze layer

			-- Check for Nulls or Duplicates in Primary key
			-- Expectation: No result
			SELECT 
			prd_id, 
			COUNT(*) 
			FROM silver.crm_prd_info
			GROUP BY cst_id
			HAVING COUNT(*) > 1 OR cst_id IS NULL

			-- Check for unwanted space
			SELECT 
			prd_nm 
			FROM silver.crm_prd_info
			WHERE prd_nm != TRIM(prd_nm)

			-- Check for NULLs or Negative Numbers
			-- Expectation: No Results
			SELECT 
			prd_cost
			FROM silver.crm_prd_info
			WHERE prd_cost < 0 OR prd_cost IS NULL

			-- Check standardization and normalization
			SELECT DISTINCT prd_line
			FROM silver.crm_prd_info

			-- Check for invalid Date
			SELECT *
			FROM silver.crm_prd_info
			WHERE prd_end_dt < prd_start_dt

			/* Fill out the end date (assuming it's ok to have null end date and every records must
			have a start date - with the start date is bigger the end date previous record of the same prd
			while the time period of each record does not overlap) */

			SELECT 
				prd_id,
				prd_key,
				prd_nm,
				prd_start_dt,
				prd_end_dt,
				LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) - 1 AS prd_end_dt 
			FROM silver.crm_prd_info


			-- CLEAN AND LOAD crm_sales_details
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
			FROM silver.crm_sales_details
			WHERE sls_cust_id NOT IN (SELECT cst_id FROM bronze.crm_cust_info)

			-- Change int to date
			-- Check negative or equal to 0 int if any
			SELECT 
			NULLIF(sls_order_dt, 0) AS sls_order_dt -- replace 0 with null
			FROM silver.crm_sales_details
			WHERE sls_order_dt <= 0 
			OR LEN(sls_order_dt) != 8 -- check if int exceed the characters length to properly convert into date
			OR sls_order_dt > 20500101 OR sls_order_dt < 19000101 -- check if date exceed the boundary of the date range

			-- Check invalid order date
			SELECT * 
			FROM silver.crm_sales_details
			WHERE sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt

			-- In case business rule: sales = quantity * price, sales, quantity and price are not negative, zero or nulls
			SELECT
			sls_sales,
			sls_quantity,
			sls_price
			FROM silver.crm_sales_details
			WHERE sls_sales != sls_quantity * sls_price
			OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
			OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0
			-- Should consult the experts to handle faults => data fixed at the source systems or data fixed at the data warehouse (check for rules to make right transformation)
			-- Rules:
			-- Sales is negative, zero, null, derive it using quantity and price
			-- price is 0 or null, calculate with sales and quantity
			-- price is negative, convert to positive



			-- CLEAN AND LOAD erp_cust_az12
			-- Make sure the cid have the same pattern as the cust_id
			SELECT
			cid,
			bdate,
			gen
			FROM silver.eso_cust_az12
			WHERE cid NOT IN (SELECT cust_id FROM bronze.crm_cust_info)

			-- Identify out of range bdate
			SELECT DISTINCT 
			bdate
			FROM silver.esp_cust_az12
			WHERE bdate < '1924-01-01' -- check for very old customers OR bdate > GETDATE()

			-- Check gender granularity -> standardization and consistency
			SELECT DISTICT gen
			FROM silver.esp_cust_az12


			-- CLEAN AND LOAD erp_loc_a101
			SELECT
			cid 
			FROM silver.erp_loc_a101;
			SELECT cst_key
			FROM bronze.crm_cust_info;

			-- Check cntry consistency
			SELECT DISTINCT cntry
			FROM silver.erp_loc_a101


			-- CLEAN AND LOAD erp_loc_a101
			SELECT
			cid, 
			cat,
			subcat,
			maintenance
			FROM silver.erp_px_cat_g1v2

			SELECT DISTINCT cat
			FROM silver.erp_px_cat_g1v2

			SELECT * FROM silver.erp_px_cat_g1v2
			WHERE cat != TRIM(cat) OR subcat != TRIM(subcat) OR maintenance != TRIM(maintenance)


