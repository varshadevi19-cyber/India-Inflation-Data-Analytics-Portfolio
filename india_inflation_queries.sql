-- ============================================================================
-- PROJECT TITLE : India Inflation, Commodity Prices & Purchasing Power Analysis
-- AUTHOR        : Varsha Devi (Data Analytics Portfolio Project)
-- DATABASE      : MySQL 8.0+ / PostgreSQL 14+ / SQL Server
-- DESCRIPTION   : Schema Creation & 8 Portfolio-Grade Analytical SQL Queries
--                 featuring CTEs, Window Functions (LAG, DENSE_RANK, AVG OVER),
--                 and RBI Monetary Policy Band Analysis.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. DATABASE & TABLE SCHEMA CREATION (டேட்டாபேஸ் டேபிள் உருவாக்குதல்)
-- ----------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS india_inflation_analytics;
USE india_inflation_analytics;

DROP TABLE IF EXISTS india_inflation_data;

CREATE TABLE india_inflation_data (
    Record_ID INT PRIMARY KEY,
    Observation_Date DATE NOT NULL,
    Year INT NOT NULL,
    Quarter VARCHAR(5) NOT NULL,
    State VARCHAR(50) NOT NULL,
    Region VARCHAR(20) NOT NULL,
    Sector VARCHAR(15) NOT NULL,
    CPI_Index_Base2012 DECIMAL(6, 1),
    Headline_Inflation_YoY_Pct DECIMAL(5, 2),
    Food_Inflation_YoY_Pct DECIMAL(5, 2),
    Fuel_Inflation_YoY_Pct DECIMAL(5, 2),
    Housing_Inflation_YoY_Pct DECIMAL(5, 2),
    Healthcare_Inflation_YoY_Pct DECIMAL(5, 2),
    RBI_Repo_Rate_Pct DECIMAL(4, 2),
    Rice_Price_INR_Kg DECIMAL(6, 2),
    Toor_Dal_Price_INR_Kg DECIMAL(6, 2),
    Milk_Price_INR_Litre DECIMAL(6, 2),
    Petrol_Price_INR_Litre DECIMAL(6, 2),
    LPG_Cylinder_INR DECIMAL(7, 2),
    Purchasing_Power_of_1000_INR DECIMAL(7, 2),
    RBI_Band_Status VARCHAR(40)
);


-- ----------------------------------------------------------------------------
-- QUERY 1: National Annual Inflation & Purchasing Power Erosion Trend
-- Business Question: ஆண்டுக்கு ஆண்டு இந்தியாவின் சராசரி பணவீக்கம், RBI ரெப்போ வட்டி
-- விகிதம் மற்றும் ₹1,000-ன் உண்மையான வாங்கும் திறன் எப்படி மாறியுள்ளது?
-- ----------------------------------------------------------------------------
SELECT 
    Year,
    ROUND(AVG(Headline_Inflation_YoY_Pct), 2) AS Avg_Headline_Inflation_Pct,
    ROUND(AVG(Food_Inflation_YoY_Pct), 2) AS Avg_Food_Inflation_Pct,
    ROUND(AVG(Fuel_Inflation_YoY_Pct), 2) AS Avg_Fuel_Inflation_Pct,
    ROUND(AVG(RBI_Repo_Rate_Pct), 2) AS Avg_RBI_Repo_Rate_Pct,
    ROUND(AVG(RBI_Repo_Rate_Pct - Headline_Inflation_YoY_Pct), 2) AS Real_Interest_Rate_Pct,
    ROUND(AVG(Purchasing_Power_of_1000_INR), 2) AS Real_Value_of_1000_INR,
    ROUND(1000.0 - AVG(Purchasing_Power_of_1000_INR), 2) AS Purchasing_Power_Lost_INR
FROM india_inflation_data
GROUP BY Year
ORDER BY Year ASC;


-- ----------------------------------------------------------------------------
-- QUERY 2: RBI Upper Tolerance Band (>6%) Breach Analysis by State
-- Business Question: எந்தெந்த மாநிலங்களில் பணவீக்கம் RBI-ன் உச்ச வரம்பான 6%-ஐத்
-- தாண்டி அதிக காலாண்டுகள் நீடித்தது?
-- ----------------------------------------------------------------------------
SELECT 
    State,
    Region,
    COUNT(*) AS Total_State_Sector_Observations,
    SUM(CASE WHEN Headline_Inflation_YoY_Pct > 6.0 THEN 1 ELSE 0 END) AS Breach_Count_Above_6Pct,
    ROUND(
        SUM(CASE WHEN Headline_Inflation_YoY_Pct > 6.0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 
        2
    ) AS Breach_Frequency_Pct,
    ROUND(MAX(Headline_Inflation_YoY_Pct), 2) AS Peak_Inflation_Recorded_Pct
FROM india_inflation_data
GROUP BY State, Region
ORDER BY Breach_Frequency_Pct DESC, Peak_Inflation_Recorded_Pct DESC;


-- ----------------------------------------------------------------------------
-- QUERY 3: Quarter-over-Quarter (QoQ) Inflation Surge using LAG() Window Function
-- Business Question: முந்தைய காலாண்டுடன் ஒப்பிடும்போது (QoQ) தமிழ்நாட்டில் நகர்ப்புற
-- மற்றும் கிராமப்புறப் பணவீக்கம் எவ்வளவு உயர்ந்தது அல்லது குறைந்தது?
-- ----------------------------------------------------------------------------
WITH TamilNadu_Trend AS (
    SELECT 
        Observation_Date,
        Year,
        Quarter,
        Sector,
        Headline_Inflation_YoY_Pct,
        Food_Inflation_YoY_Pct,
        LAG(Headline_Inflation_YoY_Pct, 1) OVER (
            PARTITION BY Sector 
            ORDER BY Observation_Date
        ) AS Prev_Quarter_Inflation_Pct
    FROM india_inflation_data
    WHERE State = 'Tamil Nadu'
)
SELECT 
    Year,
    Quarter,
    Sector,
    Headline_Inflation_YoY_Pct,
    Prev_Quarter_Inflation_Pct,
    ROUND(Headline_Inflation_YoY_Pct - Prev_Quarter_Inflation_Pct, 2) AS QoQ_Inflation_Change_Pct,
    CASE 
        WHEN (Headline_Inflation_YoY_Pct - Prev_Quarter_Inflation_Pct) > 0.50 THEN 'Sharp Acceleration'
        WHEN (Headline_Inflation_YoY_Pct - Prev_Quarter_Inflation_Pct) < -0.50 THEN 'Significant Cooling'
        ELSE 'Stable / Moderate'
    END AS Inflation_Momentum
FROM TamilNadu_Trend
ORDER BY Sector, Observation_Date;


-- ----------------------------------------------------------------------------
-- QUERY 4: Top 3 Highest Inflation States Each Year using DENSE_RANK()
-- Business Question: ஒவ்வொரு ஆண்டும் அதிக பணவீக்கத்தைச் சந்தித்த முதல் 3
-- மாநிலங்கள் எவை?
-- ----------------------------------------------------------------------------
WITH State_Annual_Inflation AS (
    SELECT 
        Year,
        State,
        Region,
        ROUND(AVG(Headline_Inflation_YoY_Pct), 2) AS Annual_Avg_Inflation_Pct,
        ROUND(AVG(Food_Inflation_YoY_Pct), 2) AS Annual_Avg_Food_Inflation_Pct
    FROM india_inflation_data
    GROUP BY Year, State, Region
),
Ranked_States AS (
    SELECT 
        Year,
        State,
        Region,
        Annual_Avg_Inflation_Pct,
        Annual_Avg_Food_Inflation_Pct,
        DENSE_RANK() OVER (
            PARTITION BY Year 
            ORDER BY Annual_Avg_Inflation_Pct DESC
        ) AS Inflation_Rank
    FROM State_Annual_Inflation
)
SELECT 
    Year,
    Inflation_Rank,
    State,
    Region,
    Annual_Avg_Inflation_Pct,
    Annual_Avg_Food_Inflation_Pct
FROM Ranked_States
WHERE Inflation_Rank <= 3
ORDER BY Year ASC, Inflation_Rank ASC;


-- ----------------------------------------------------------------------------
-- QUERY 5: Rural vs Urban Sector Inflation & Commodity Cost Gap
-- Business Question: கிராமப்புறத்திற்கும் நகர்ப்புறத்திற்கும் இடையே உணவு மற்றும்
-- வீட்டுவசதிப் பணவீக்கத்தில் உள்ள வேறுபாடு என்ன?
-- ----------------------------------------------------------------------------
SELECT 
    Year,
    ROUND(AVG(CASE WHEN Sector = 'Rural' THEN Food_Inflation_YoY_Pct END), 2) AS Rural_Food_Inflation_Pct,
    ROUND(AVG(CASE WHEN Sector = 'Urban' THEN Food_Inflation_YoY_Pct END), 2) AS Urban_Food_Inflation_Pct,
    ROUND(
        AVG(CASE WHEN Sector = 'Rural' THEN Food_Inflation_YoY_Pct END) - 
        AVG(CASE WHEN Sector = 'Urban' THEN Food_Inflation_YoY_Pct END), 2
    ) AS Rural_Urban_Food_Gap_Pct,
    ROUND(AVG(CASE WHEN Sector = 'Urban' THEN Housing_Inflation_YoY_Pct END), 2) AS Urban_Housing_Inflation_Pct,
    ROUND(AVG(CASE WHEN Sector = 'Rural' THEN Housing_Inflation_YoY_Pct END), 2) AS Rural_Housing_Inflation_Pct
FROM india_inflation_data
GROUP BY Year
ORDER BY Year ASC;


-- ----------------------------------------------------------------------------
-- QUERY 6: 4-Quarter Rolling Average Inflation (Moving Average Window Function)
-- Business Question: பருவகால ஏற்ற இறக்கங்களை நீக்கிப் பார்க்க, 4-காலாண்டு நகரும்
-- சராசரி (4-Quarter Moving Average) பணவீக்கம் எவ்வாறு உள்ளது?
-- ----------------------------------------------------------------------------
SELECT 
    State,
    Sector,
    Year,
    Quarter,
    Headline_Inflation_YoY_Pct,
    ROUND(
        AVG(Headline_Inflation_YoY_Pct) OVER (
            PARTITION BY State, Sector 
            ORDER BY Observation_Date 
            ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
        ), 2
    ) AS Rolling_4Q_Avg_Inflation_Pct
FROM india_inflation_data
WHERE State IN ('Tamil Nadu', 'Maharashtra', 'Karnataka', 'Delhi')
  AND Sector = 'Urban'
ORDER BY State, Observation_Date;


-- ----------------------------------------------------------------------------
-- QUERY 7: Essential Household Grocery & Fuel Basket Surge (2019 vs 2025)
-- Business Question: 2019-ஆம் ஆண்டுடன் ஒப்பிடும்போது 2025-ல் ஒரு சராசரி இந்தியக்
-- குடும்பத்தின் அத்தியாவசியப் பொருட்கள் (அரிசி, பருப்பு, பால், சிலிண்டர்) செலவு
-- எத்தனை சதவீதம் உயர்ந்துள்ளது?
-- ----------------------------------------------------------------------------
WITH Basket_Calc AS (
    SELECT 
        State,
        Year,
        AVG(
            (10 * Rice_Price_INR_Kg) + 
            (3 * Toor_Dal_Price_INR_Kg) + 
            (15 * Milk_Price_INR_Litre) + 
            (1 * LPG_Cylinder_INR)
        ) AS Avg_Monthly_Basket_INR
    FROM india_inflation_data
    WHERE Year IN (2019, 2025)
    GROUP BY State, Year
)
SELECT 
    b19.State,
    ROUND(b19.Avg_Monthly_Basket_INR, 2) AS Basket_Cost_2019_INR,
    ROUND(b25.Avg_Monthly_Basket_INR, 2) AS Basket_Cost_2025_INR,
    ROUND(b25.Avg_Monthly_Basket_INR - b19.Avg_Monthly_Basket_INR, 2) AS Absolute_Cost_Increase_INR,
    ROUND(
        ((b25.Avg_Monthly_Basket_INR - b19.Avg_Monthly_Basket_INR) / b19.Avg_Monthly_Basket_INR) * 100, 
        2
    ) AS Basket_Price_Growth_Pct
FROM Basket_Calc b19
JOIN Basket_Calc b25 
    ON b19.State = b25.State 
   AND b19.Year = 2019 
   AND b25.Year = 2025
ORDER BY Basket_Price_Growth_Pct DESC;


-- ----------------------------------------------------------------------------
-- QUERY 8: Monetary Policy Effectiveness (Repo Rate Hike Impact Analysis)
-- Business Question: RBI ரெப்போ வட்டி விகிதத்தை 6.50% ஆக உயர்த்திய பிறகு (2023-2024),
-- பணவீக்கம் எவ்வாறு கட்டுக்குள் வந்தது?
-- ----------------------------------------------------------------------------
SELECT 
    CASE 
        WHEN RBI_Repo_Rate_Pct < 4.50 THEN '1. Accommodative Low Rate (<4.5%)'
        WHEN RBI_Repo_Rate_Pct BETWEEN 4.50 AND 6.00 THEN '2. Neutral / Transition Rate (4.5%-6.0%)'
        ELSE '3. Tightening High Repo Rate (>6.0%)'
    END AS Monetary_Policy_Regime,
    COUNT(*) AS Total_Observations,
    ROUND(AVG(Headline_Inflation_YoY_Pct), 2) AS Avg_Headline_CPI_Pct,
    ROUND(AVG(Food_Inflation_YoY_Pct), 2) AS Avg_Food_CPI_Pct,
    ROUND(AVG(Fuel_Inflation_YoY_Pct), 2) AS Avg_Fuel_CPI_Pct
FROM india_inflation_data
GROUP BY 
    CASE 
        WHEN RBI_Repo_Rate_Pct < 4.50 THEN '1. Accommodative Low Rate (<4.5%)'
        WHEN RBI_Repo_Rate_Pct BETWEEN 4.50 AND 6.00 THEN '2. Neutral / Transition Rate (4.5%-6.0%)'
        ELSE '3. Tightening High Repo Rate (>6.0%)'
    END
ORDER BY Monetary_Policy_Regime;