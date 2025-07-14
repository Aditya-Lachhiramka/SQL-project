USE mavenfuzzyfactory;

-- Part 1: Gsearch sessions and orders by month to show growth trend
SELECT
	YEAR(website_sessions.created_at) AS yr, 
    MONTH(website_sessions.created_at) AS mo, 
    COUNT(DISTINCT website_sessions.website_session_id) AS sessions, 
    COUNT(DISTINCT orders.order_id) AS orders, 
    COUNT(DISTINCT orders.order_id)/COUNT(DISTINCT website_sessions.website_session_id) AS conv_rate
FROM website_sessions
	LEFT JOIN orders 
		ON orders.website_session_id = website_sessions.website_session_id
WHERE website_sessions.created_at < '2012-11-27'
	AND website_sessions.utm_source = 'gsearch'
GROUP BY 1,2;

-- Part 2: Gsearch trend split into nonbrand and brand campaigns
SELECT
	YEAR(website_sessions.created_at) AS yr, 
    MONTH(website_sessions.created_at) AS mo, 
    COUNT(DISTINCT CASE WHEN utm_campaign = 'nonbrand' THEN website_sessions.website_session_id END) AS nonbrand_sessions, 
    COUNT(DISTINCT CASE WHEN utm_campaign = 'nonbrand' THEN orders.order_id END) AS nonbrand_orders,
    COUNT(DISTINCT CASE WHEN utm_campaign = 'brand' THEN website_sessions.website_session_id END) AS brand_sessions, 
    COUNT(DISTINCT CASE WHEN utm_campaign = 'brand' THEN orders.order_id END) AS brand_orders
FROM website_sessions
	LEFT JOIN orders 
		ON orders.website_session_id = website_sessions.website_session_id
WHERE website_sessions.created_at < '2012-11-27'
	AND website_sessions.utm_source = 'gsearch'
GROUP BY 1,2;

-- Part 3: Gsearch nonbrand orders and sessions split by device type
SELECT
	YEAR(website_sessions.created_at) AS yr, 
    MONTH(website_sessions.created_at) AS mo, 
    COUNT(DISTINCT CASE WHEN device_type = 'desktop' THEN website_sessions.website_session_id END) AS desktop_sessions, 
    COUNT(DISTINCT CASE WHEN device_type = 'desktop' THEN orders.order_id END) AS desktop_orders,
    COUNT(DISTINCT CASE WHEN device_type = 'mobile' THEN website_sessions.website_session_id END) AS mobile_sessions, 
    COUNT(DISTINCT CASE WHEN device_type = 'mobile' THEN orders.order_id END) AS mobile_orders
FROM website_sessions
	LEFT JOIN orders 
		ON orders.website_session_id = website_sessions.website_session_id
WHERE website_sessions.created_at < '2012-11-27'
	AND website_sessions.utm_source = 'gsearch'
    AND website_sessions.utm_campaign = 'nonbrand'
GROUP BY 1,2;

-- Part 4: Compare Gsearch vs other channels for sessions by month
SELECT
	YEAR(website_sessions.created_at) AS yr, 
    MONTH(website_sessions.created_at) AS mo, 
    COUNT(DISTINCT CASE WHEN utm_source = 'gsearch' THEN website_sessions.website_session_id END) AS gsearch_paid_sessions,
    COUNT(DISTINCT CASE WHEN utm_source = 'bsearch' THEN website_sessions.website_session_id END) AS bsearch_paid_sessions,
    COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IS NOT NULL THEN website_sessions.website_session_id END) AS organic_search_sessions,
    COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IS NULL THEN website_sessions.website_session_id END) AS direct_type_in_sessions
FROM website_sessions
	LEFT JOIN orders 
		ON orders.website_session_id = website_sessions.website_session_id
WHERE website_sessions.created_at < '2012-11-27'
GROUP BY 1,2;

-- Part 5: Monthly conversion rate trends to measure site improvements
SELECT
	YEAR(website_sessions.created_at) AS yr, 
    MONTH(website_sessions.created_at) AS mo, 
    COUNT(DISTINCT website_sessions.website_session_id) AS sessions, 
    COUNT(DISTINCT orders.order_id) AS orders, 
    COUNT(DISTINCT orders.order_id)/COUNT(DISTINCT website_sessions.website_session_id) AS conversion_rate    
FROM website_sessions
	LEFT JOIN orders 
		ON orders.website_session_id = website_sessions.website_session_id
WHERE website_sessions.created_at < '2012-11-27'
GROUP BY 1,2;

-- Part 6: Estimating incremental revenue from the gsearch lander test
CREATE TEMPORARY TABLE first_test_pageviews
SELECT
	website_pageviews.website_session_id, 
    MIN(website_pageviews.website_pageview_id) AS min_pageview_id
FROM website_pageviews 
	INNER JOIN website_sessions 
		ON website_sessions.website_session_id = website_pageviews.website_session_id
		AND website_sessions.created_at < '2012-07-28'
		AND website_pageviews.website_pageview_id >= 23504
        AND utm_source = 'gsearch'
        AND utm_campaign = 'nonbrand'
GROUP BY website_pageviews.website_session_id;

CREATE TEMPORARY TABLE nonbrand_test_sessions_w_landing_pages
SELECT 
	first_test_pageviews.website_session_id, 
    website_pageviews.pageview_url AS landing_page
FROM first_test_pageviews
	LEFT JOIN website_pageviews 
		ON website_pageviews.website_pageview_id = first_test_pageviews.min_pageview_id
WHERE website_pageviews.pageview_url IN ('/home','/lander-1');

CREATE TEMPORARY TABLE nonbrand_test_sessions_w_orders
SELECT
	nonbrand_test_sessions_w_landing_pages.website_session_id, 
    nonbrand_test_sessions_w_landing_pages.landing_page, 
    orders.order_id
FROM nonbrand_test_sessions_w_landing_pages
LEFT JOIN orders 
	ON orders.website_session_id = nonbrand_test_sessions_w_landing_pages.website_session_id;

SELECT
	landing_page, 
    COUNT(DISTINCT website_session_id) AS sessions, 
    COUNT(DISTINCT order_id) AS orders,
    COUNT(DISTINCT order_id)/COUNT(DISTINCT website_session_id) AS conv_rate
FROM nonbrand_test_sessions_w_orders
GROUP BY 1;

-- Part 7: Build a full funnel view for the gsearch lander test
CREATE TEMPORARY TABLE session_level_made_it_flagged
SELECT
	website_session_id, 
    MAX(CASE WHEN pageview_url = '/home' THEN 1 ELSE 0 END) AS saw_homepage, 
    MAX(CASE WHEN pageview_url = '/lander-1' THEN 1 ELSE 0 END) AS saw_custom_lander,
    MAX(CASE WHEN pageview_url = '/products' THEN 1 ELSE 0 END) AS product_made_it, 
    MAX(CASE WHEN pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END) AS mrfuzzy_made_it, 
    MAX(CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END) AS cart_made_it,
    MAX(CASE WHEN pageview_url = '/shipping' THEN 1 ELSE 0 END) AS shipping_made_it,
    MAX(CASE WHEN pageview_url = '/billing' THEN 1 ELSE 0 END) AS billing_made_it,
    MAX(CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END) AS thankyou_made_it
FROM website_sessions 
	LEFT JOIN website_pageviews 
		ON website_sessions.website_session_id = website_pageviews.website_session_id
WHERE utm_source = 'gsearch' 
	AND utm_campaign = 'nonbrand' 
    AND website_sessions.created_at BETWEEN '2012-06-19' AND '2012-07-28'
GROUP BY website_session_id;

SELECT
	CASE WHEN saw_homepage = 1 THEN 'saw_homepage'
         WHEN saw_custom_lander = 1 THEN 'saw_custom_lander'
         ELSE 'check logic' 
	END AS segment, 
    COUNT(DISTINCT website_session_id) AS sessions,
    COUNT(DISTINCT CASE WHEN product_made_it = 1 THEN website_session_id END) AS to_products,
    COUNT(DISTINCT CASE WHEN mrfuzzy_made_it = 1 THEN website_session_id END) AS to_mrfuzzy,
    COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id END) AS to_cart,
    COUNT(DISTINCT CASE WHEN shipping_made_it = 1 THEN website_session_id END) AS to_shipping,
    COUNT(DISTINCT CASE WHEN billing_made_it = 1 THEN website_session_id END) AS to_billing,
    COUNT(DISTINCT CASE WHEN thankyou_made_it = 1 THEN website_session_id END) AS to_thankyou
FROM session_level_made_it_flagged 
GROUP BY 1;

-- Part 8: Billing test impact, revenue per billing session
SELECT
	billing_version_seen, 
    COUNT(DISTINCT website_session_id) AS sessions, 
    SUM(price_usd)/COUNT(DISTINCT website_session_id) AS revenue_per_billing_page_seen
FROM( 
SELECT 
	website_pageviews.website_session_id, 
    website_pageviews.pageview_url AS billing_version_seen, 
    orders.order_id, 
    orders.price_usd
FROM website_pageviews 
	LEFT JOIN orders
		ON orders.website_session_id = website_pageviews.website_session_id
WHERE website_pageviews.created_at BETWEEN '2012-09-10' AND '2012-11-10'
	AND website_pageviews.pageview_url IN ('/billing','/billing-2')
) AS billing_pageviews_and_order_data
GROUP BY 1;

-- Check number of billing sessions last month for extrapolating impact
SELECT 
	COUNT(website_session_id) AS billing_sessions_past_month
FROM website_pageviews 
WHERE website_pageviews.pageview_url IN ('/billing','/billing-2') 
	AND created_at BETWEEN '2012-10-27' AND '2012-11-27';

-- Final: Company-wide quarterly growth, efficiency, channel mix, product performance
SELECT 
	YEAR(website_sessions.created_at) AS yr,
	QUARTER(website_sessions.created_at) AS qtr, 
	COUNT(DISTINCT website_sessions.website_session_id) AS sessions, 
    COUNT(DISTINCT orders.order_id) AS orders
FROM website_sessions 
	LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id
GROUP BY 1,2
ORDER BY 1,2;

SELECT 
	YEAR(website_sessions.created_at) AS yr,
	QUARTER(website_sessions.created_at) AS qtr, 
	COUNT(DISTINCT orders.order_id)/COUNT(DISTINCT website_sessions.website_session_id) AS session_to_order_conv_rate, 
    SUM(price_usd)/COUNT(DISTINCT orders.order_id) AS revenue_per_order, 
    SUM(price_usd)/COUNT(DISTINCT website_sessions.website_session_id) AS revenue_per_session
FROM website_sessions 
	LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id
GROUP BY 1,2
ORDER BY 1,2;

SELECT 
	YEAR(created_at) AS yr, 
    MONTH(created_at) AS mo, 
    SUM(CASE WHEN product_id = 1 THEN price_usd ELSE NULL END) AS mrfuzzy_rev,
    SUM(CASE WHEN product_id = 1 THEN price_usd - cogs_usd ELSE NULL END) AS mrfuzzy_marg,
    SUM(CASE WHEN product_id = 2 THEN price_usd ELSE NULL END) AS lovebear_rev,
    SUM(CASE WHEN product_id = 2 THEN price_usd - cogs_usd ELSE NULL END) AS lovebear_marg,
    SUM(CASE WHEN product_id = 3 THEN price_usd ELSE NULL END) AS birthdaybear_rev,
    SUM(CASE WHEN product_id = 3 THEN price_usd - cogs_usd ELSE NULL END) AS birthdaybear_marg,
    SUM(CASE WHEN product_id = 4 THEN price_usd ELSE NULL END) AS minibear_rev,
    SUM(CASE WHEN product_id = 4 THEN price_usd - cogs_usd ELSE NULL END) AS minibear_marg,
    SUM(price_usd) AS total_revenue,  
    SUM(price_usd - cogs_usd) AS total_margin
FROM order_items 
GROUP BY 1,2
ORDER BY 1,2;

CREATE TEMPORARY TABLE products_pageviews
SELECT
	website_session_id, 
    website_pageview_id, 
    created_at AS saw_product_page_at
FROM website_pageviews 
WHERE pageview_url = '/products';

SELECT 
	YEAR(saw_product_page_at) AS yr, 
    MONTH(saw_product_page_at) AS mo,
    COUNT(DISTINCT products_pageviews.website_session_id) AS sessions_to_product_page, 
    COUNT(DISTINCT website_pageviews.website_session_id) AS clicked_to_next_page, 
    COUNT(DISTINCT website_pageviews.website_session_id)/COUNT(DISTINCT products_pageviews.website_session_id) AS clickthrough_rt,
    COUNT(DISTINCT orders.order_id) AS orders,
    COUNT(DISTINCT orders.order_id)/COUNT(DISTINCT products_pageviews.website_session_id) AS products_to_order_rt
FROM products_pageviews
	LEFT JOIN website_pageviews 
		ON website_pageviews.website_session_id = products_pageviews.website_session_id
        AND website_pageviews.website_pageview_id > products_pageviews.website_pageview_id
	LEFT JOIN orders 
		ON orders.website_session_id = products_pageviews.website_session_id
GROUP BY 1,2;

CREATE TEMPORARY TABLE primary_products
SELECT 
	order_id, 
    primary_product_id
FROM orders 
WHERE created_at > '2014-12-05';

SELECT 
	primary_product_id, 
    COUNT(DISTINCT order_id) AS total_orders, 
    COUNT(DISTINCT CASE WHEN order_items.product_id = 1 AND order_items.is_primary_item = 0 THEN order_id END) AS xsold_p1,
    COUNT(DISTINCT CASE WHEN order_items.product_id = 2 AND order_items.is_primary_item = 0 THEN order_id END) AS xsold_p2,
    COUNT(DISTINCT CASE WHEN order_items.product_id = 3 AND order_items.is_primary_item = 0 THEN order_id END) AS xsold_p3,
    COUNT(DISTINCT CASE WHEN order_items.product_id = 4 AND order_items.is_primary_item = 0 THEN order_id END) AS xsold_p4
FROM primary_products
	LEFT JOIN order_items 
		ON order_items.order_id = primary_products.order_id
GROUP BY 1;
