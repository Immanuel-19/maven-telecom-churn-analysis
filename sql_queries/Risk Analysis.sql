-- What percentage of customers using the different internet types churned?

SELECT
    Internet_Type,
    COUNT(*) AS TotalCustomers,
    SUM
		(
			CASE
				WHEN Customer_Status = 'Churned' THEN 1
				ELSE 0
			END
		) AS ChurnedCustomers,
	ROUND(SUM
		(
			CASE
				WHEN Customer_Status = 'Churned' THEN 1
				ELSE 0
			END
		) * 100 / CAST(COUNT(*) AS FLOAT), 2) AS ChurnRate
FROM
    telecom_customer_churn
GROUP BY
    Internet_Type
ORDER BY
	ChurnRate DESC



-- Since Fiber optic customers has a high likelihood of churning, we can see what contract type they use and which has more churn rate

SELECT
	Contract,
	COUNT(*) AS TotalCustomers,
	SUM
		(
			CASE 
				WHEN Customer_Status = 'Churned' THEN 1
				ELSE 0
			END
		) AS ChurnedCustomers,
	ROUND(SUM
		(
			CASE 
				WHEN Customer_Status = 'Churned' THEN 1
				ELSE 0
			END
		) * 100 / CAST(COUNT(*) AS FLOAT), 2) AS ChurnRate
FROM
	telecom_customer_churn
WHERE 
	Internet_Type = 'Fiber Optic'
GROUP BY
	Contract