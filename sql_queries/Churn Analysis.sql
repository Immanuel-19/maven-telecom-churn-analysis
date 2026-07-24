-- Maven Telecom Churn Analysis


-- Checking for Duplicates

SELECT
	Customer_ID,
	COUNT(*) AS CustomerCount
FROM
	telecom_customer_churn
GROUP BY
	Customer_ID
HAVING 
	COUNT(*) > 1



-- How many customers joined the company during the last quarter?

SELECT
	COUNT(*)
FROM 
	telecom_customer_churn
WHERE
	Tenure_in_Months >= 1 AND Tenure_in_Months <= 3


WITH LastQuarter AS
	(
		SELECT
			DATEADD(MONTH, -3, GETDATE()) AS StartOfLastQuarter
	)

SELECT
	COUNT(*) AS CustomerJoinedLastQuarter
FROM
	telecom_customer_churn
WHERE 
	DATEADD(MONTH, - Tenure_in_Months, GETDATE()) >= (
		SELECT
			StartOfLastQuarter
		FROM
			LastQuarter
	)



-- What are the key drivers of churn? 

SELECT
	Churn_Category,
	Churn_reason,
	COUNT(*) AS Customers
FROM
	telecom_customer_churn
WHERE
	Customer_Status = 'Churned'
GROUP BY
	Churn_Category,
	Churn_Reason
ORDER BY
	COUNT(*) DESC;



-- What contract are churners on and what percentage of churners are on each contract?

SELECT
	[Contract],
	COUNT(*) AS Customers,
	ROUND((CAST(COUNT(*) AS FLOAT) / 
		(
			SELECT
				COUNT(Customer_ID) AS ChurnedCount
			FROM
				telecom_customer_churn
			WHERE
				Customer_Status = 'Churned'
		)
	) * 100, 2) AS PercentageChurned
FROM
	telecom_customer_churn
WHERE
	Customer_Status = 'Churned'
GROUP BY
	[Contract]
ORDER BY
	COUNT(*) DESC

	
-- OR (Using Window Functions)


SELECT
	[Contract],
	COUNT(*) AS Customers,
	ROUND((CAST(COUNT(*) AS FLOAT) / SUM(COUNT(*)) OVER()) * 100, 2) AS PercentageChurned -- The Window function is computed after grouping & aggregation
FROM
	telecom_customer_churn
WHERE
	Customer_Status = 'Churned'
GROUP BY
	[Contract]
ORDER BY
	COUNT(*) DESC


-- Are Churned customers subscribed to premium tech support?

SELECT
	Premium_Tech_Support,
	COUNT(*) AS Customers, 
	ROUND((CAST(COUNT(*) AS FLOAT) / SUM(COUNT(*)) OVER()) * 100, 2) AS PercentageChurned
FROM
	telecom_customer_churn
WHERE
	Customer_Status = 'Churned'
GROUP BY
	Premium_Tech_Support
ORDER BY 
	COUNT(*) DESC



-- What Internet Type do churned customers use?

SELECT
	Internet_Type,
	COUNT(*) AS Customers, 
	ROUND((CAST(COUNT(*) AS FLOAT) / SUM(COUNT(*)) OVER()) * 100, 2) AS PercentageChurned
FROM
	telecom_customer_churn
WHERE
	Customer_Status = 'Churned'
GROUP BY
	Internet_Type
ORDER BY 
	COUNT(*) DESC



-- What marketing offer where churned customers offered?

SELECT
	Offer,
	COUNT(*) AS Customers, 
	ROUND((CAST(COUNT(*) AS FLOAT) / SUM(COUNT(*)) OVER()) * 100, 2) AS PercentageChurned
FROM
	telecom_customer_churn
WHERE
	Customer_Status = 'Churned'
GROUP BY
	Offer
ORDER BY 
	COUNT(*) DESC

-- Which offer has the highest likelihood of customers churning
SELECT
    Offer,
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
    Offer
ORDER BY
	ChurnRate DESC



-- Which high-value customers are at risk of churning?

SELECT
	ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY Monthly_Charge) OVER(), 0) AS MedianMonthlyCharge
FROM
	telecom_customer_churn
;


-- Measuring the Risk Level of customers

WITH CustomerRiskLevel AS
	(
		SELECT
			Customer_ID,
			Customer_Status,
			Offer,
			Premium_Tech_Support,
			Contract,
			Internet_Type,
			CASE
				WHEN 
					(
						CASE WHEN Offer = 'None' THEN 1 ELSE 0 END +
						CASE WHEN Premium_Tech_Support = 'No' THEN 1 ELSE 0 END +
						CASE WHEN Contract = 'Month-to-Month' THEN 1 ELSE 0 END +
						CASE WHEN Internet_Type = 'Fiber Optic' THEN 1 ELSE 0 END 
					) >= 3 THEN 'High Risk'
				WHEN
					(
						CASE WHEN Offer = 'None' THEN 1 ELSE 0 END +
						CASE WHEN Premium_Tech_Support = 'No' THEN 1 ELSE 0 END +
						CASE WHEN Contract = 'Month-to-Month' THEN 1 ELSE 0 END +
						CASE WHEN Internet_Type = 'Fiber Optic' THEN 1 ELSE 0 END
					) = 2 THEN 'Medium Risk'
				ELSE 'Low Risk'
			END AS "RiskLevel"
		FROM
			telecom_customer_churn
	)

SELECT
	*
FROM
	CustomerRiskLevel
WHERE
	Customer_Status <> 'Churned' AND RiskLevel = 'High Risk'
;


-- Measuring Customer value

WITH Median AS 
	(
		SELECT
			DISTINCT ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY Monthly_Charge) OVER(), 0) AS MedianMonthlyCharge
		FROM
			telecom_customer_churn
	)

SELECT
	t.Customer_ID,
	t.Number_of_Referrals,
	t.Monthly_Charge,
	t.Tenure_in_Months,
	CASE 
		WHEN Number_of_Referrals > 0 AND Monthly_Charge >= MedianMonthlyCharge AND Tenure_in_Months > 9 THEN 'High Priority'
		WHEN 
			(
				(Number_of_Referrals > 0 AND Monthly_Charge >= MedianMonthlyCharge) OR
				(Tenure_in_Months > 9 AND Monthly_Charge >= MedianMonthlyCharge) OR 
				(Number_of_Referrals > 0 AND Tenure_in_Months > 9)
			) THEN 'Medium Priority'
		ELSE 'Low Priority'
	END AS CustomerValue
FROM
	telecom_customer_churn AS t
CROSS JOIN 
	Median
WHERE 
	Customer_Status <> 'Churned'
;

-- A scoring system could be used to get the same result. We can get customers that are high-priority and are at high-risk of churning

WITH MedianCharge AS
	(
		SELECT
			DISTINCT ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY Monthly_Charge) OVER(), 0) AS MedianChargeValue
		FROM
			telecom_customer_churn
	),

	PriorityRiskLevel AS 
		(
			SELECT
				*,
				CASE
					WHEN Score = 3 THEN 'High Priority'
					WHEN Score = 2 THEN 'Medium Priority'
					ELSE 'Low Priority'
				END AS CustomerPriority,
				CASE
					WHEN RiskScore >= 3 THEN 'High Risk'
					WHEN RiskScore = 2 THEN 'Medium Risk'
					ELSE 'Low Risk'
				END AS CustomerRiskLevel
			FROM
				(
					SELECT
						t.Customer_ID,
						t.Number_of_Referrals,
						t.Monthly_Charge,
						t.Tenure_in_Months,

						(
							CASE 
								WHEN Number_of_Referrals > 0 THEN 1 ELSE 0 END +
							CASE 
								WHEN Monthly_Charge >= MedianChargeValue THEN 1 ELSE 0 END +
							CASE
								WHEN Tenure_in_Months > 9 THEN 1 ELSE 0 END
						) AS Score,
			
						(
							CASE 
								WHEN Offer = 'None' THEN 1 ELSE 0 END +
							CASE 
								WHEN Premium_Tech_Support = 'No' THEN 1 ELSE 0 END +
							CASE 
								WHEN Contract = 'Month-to-Month' THEN 1 ELSE 0 END +
							CASE 
								WHEN Internet_Type = 'Fiber Optic' THEN 1 ELSE 0 END 
						) AS RiskScore

					FROM
						telecom_customer_churn AS t
					CROSS JOIN
						MedianCharge
					WHERE 
						Customer_Status <> 'Churned'
				) AS t
		)

SELECT
	*
FROM
	PriorityRiskLevel
WHERE
	CustomerPriority = 'High Priority' AND CustomerRiskLevel = 'High Risk'



/* WITH CustomerProfile AS (
    SELECT Gender, Age, Married, Number_of_Dependents, Customer_Status,
           ROW_NUMBER() OVER (PARTITION BY Customer_Status ORDER BY Age) AS RowNum
    FROM telecom_customer_churn
)
SELECT Customer_Status, Gender, Married, 
       AVG(CAST ([Age] AS INT)) AS Avg_Age, 
       AVG(CAST (Number_of_Dependents AS INT)) AS Avg_Dependents,
       COUNT(*) AS Total_Customers
FROM CustomerProfile
GROUP BY Customer_Status, Gender, Married
ORDER BY Customer_Status;
*/