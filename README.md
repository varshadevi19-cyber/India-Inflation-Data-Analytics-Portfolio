# India-Inflation-Data-Analytics-Portfolio
India Macroeconomic Inflation, Commodity Prices & Purchasing Power Analytics (2019–2025)Complete Portfolio Project Documentation, Power BI DAX Reference & Interview GuideAuthor: Varsha DeviTech Stack: Python (Pandas, NumPy, Matplotlib, Seaborn), SQL (MySQL / PostgreSQL / SQLite), Power BI (DAX, Power Query, Data Modeling)1. Executive Summary & Business ProblemInflation is more than a macroeconomic headline figure—it directly governs household grocery budgets, fuel expenses, and the real purchasing power of personal savings. Between 2019 and 2025, India experienced major macroeconomic shifts, including COVID-19 supply-chain disruptions (2020), a global commodity and fuel price surge (2022), and an aggressive monetary tightening cycle by the Reserve Bank of India (RBI).This end-to-end Data Analytics project investigates 7 years (2019–2025, 448 quarterly state-sector observations) of Consumer Price Index (CPI) inflation, RBI Repo Rate policy regimes, and essential retail commodity prices across 8 major Indian states (Tamil Nadu, Maharashtra, Karnataka, Delhi, Uttar Pradesh, Gujarat, West Bengal, and Kerala) split by Rural and Urban sectors.Core Business Questions AnsweredPurchasing Power Erosion: How much has the real purchasing power of ₹1,000 (Base Year 2019) declined by 2025 due to cumulative inflation?RBI Tolerance Band Breaches (>6%): Which states and time periods most frequently breached the RBI's upper comfort threshold of 6.0% YoY headline inflation?Rural vs. Urban Cost-of-Living Divide: Does food inflation disproportionately impact rural households while housing inflation drives urban cost increases?Household Essential Basket Surge: By what percentage has a standard monthly household essential basket (10 kg Rice, 3 kg Toor Dal, 15 L Milk, and 1 LPG Cylinder) increased across states between 2019 and 2025?2. Dataset Dictionary (india_inflation_dataset.csv)The dataset contains 448 records and 21 attributes structured at the State × Sector × Quarter grain:Column NameData TypeDescriptionRecord_IDIntegerUnique primary key identifier for each observation (1001–1448)Observation_DateDateQuarter start date (YYYY-MM-DD)Year & QuarterInt / TextCalendar year (2019–2025) and quarter (Q1 to Q4)State & RegionTextIndian state name and geographical zone (South, North, West, East)SectorTextDemographic sector (Urban or Rural)CPI_Index_Base2012DecimalConsumer Price Index value (Base Year 2012 = 100)Headline_Inflation_YoY_PctDecimalYear-over-Year combined headline CPI inflation rate (%)Food_Inflation_YoY_PctDecimalYear-over-Year food and beverages inflation rate (%)Fuel_Inflation_YoY_PctDecimalYear-over-Year fuel and light inflation rate (%)Housing_Inflation_YoY_PctDecimalYear-over-Year housing and rent inflation rate (%)Healthcare_Inflation_YoY_PctDecimalYear-over-Year healthcare expenditure inflation rate (%)RBI_Repo_Rate_PctDecimalPrevailing RBI monetary policy repo rate (%) during the quarterRice_Price_INR_KgDecimalAverage retail price of 1 kg Rice (₹)Toor_Dal_Price_INR_KgDecimalAverage retail price of 1 kg Toor Dal / Arhar Dal (₹)Milk_Price_INR_LitreDecimalAverage retail price of 1 litre Milk (₹)Petrol_Price_INR_LitreDecimalAverage retail price of 1 litre Petrol (₹)LPG_Cylinder_INRDecimalAverage retail price of a 14.2 kg domestic LPG cylinder (₹)Purchasing_Power_of_1000_INRDecimalReal value of ₹1,000 relative to 2019 purchasing power (₹)RBI_Band_StatusTextPolicy band classification (Below Target <4%, Within Comfort Zone 4%-6%, Above Upper Tolerance >6%)3. Power BI Data Model & DAX Measures ReferenceAfter importing india_inflation_dataset.csv into Power BI Desktop via Get Data -> Text/CSV, create a dedicated Calendar Dimension Table (Dim_Calendar) and connect Dim_Calendar[Date] to india_inflation_dataset[Observation_Date] in a One-to-Many (1:*) relationship.A. Calendar Dimension Table (DAX Calculated Table)Dim_Calendar = 
ADDCOLUMNS (
    CALENDAR ( DATE ( 2019, 1, 1 ), DATE ( 2025, 12, 31 ) ),
    "Year", YEAR ( [Date] ),
    "Quarter", "Q" & FORMAT ( [Date], "Q" ),
    "Year_Quarter", YEAR ( [Date] ) & "-" & "Q" & FORMAT ( [Date], "Q" ),
    "Month_Name", FORMAT ( [Date], "MMM" )
)
B. Core KPI DAX Measures1. Average Headline Inflation (%):Avg Headline Inflation % = 
ROUND ( AVERAGE ( india_inflation_dataset[Headline_Inflation_YoY_Pct] ), 2 )
2. Average Food Inflation (%):Avg Food Inflation % = 
ROUND ( AVERAGE ( india_inflation_dataset[Food_Inflation_YoY_Pct] ), 2 )
3. Real Interest Rate (%):
(Measures the net return on savings after subtracting headline inflation from the RBI Repo Rate)Real Interest Rate % = 
VAR AvgRepo = AVERAGE ( india_inflation_dataset[RBI_Repo_Rate_Pct] )
VAR AvgCPI = [Avg Headline Inflation %]
RETURN
    ROUND ( AvgRepo - AvgCPI, 2 )
4. Real Purchasing Power of ₹1,000 (Base 2019):Purchasing Power of 1000 INR = 
ROUND ( AVERAGE ( india_inflation_dataset[Purchasing_Power_of_1000_INR] ), 0 )
5. Year-over-Year (YoY) Inflation Comparison:Prev Year Inflation % = 
CALCULATE (
    [Avg Headline Inflation %],
    SAMEPERIODLASTYEAR ( Dim_Calendar[Date] )
)
YoY Inflation Variance (bps) = 
VAR CurrentInf = [Avg Headline Inflation %]
VAR PrevInf = [Prev Year Inflation %]
RETURN
    IF ( NOT ISBLANK ( PrevInf ), ROUND ( ( CurrentInf - PrevInf ) * 100, 0 ) )
6. Monthly Household Essential Basket Cost (₹):
(Weighted monthly family consumption: 10 kg Rice + 3 kg Toor Dal + 15 L Milk + 1 LPG Cylinder)Monthly Family Basket INR = 
ROUND (
    ( 10 * AVERAGE ( india_inflation_dataset[Rice_Price_INR_Kg] ) ) +
    ( 3 * AVERAGE ( india_inflation_dataset[Toor_Dal_Price_INR_Kg] ) ) +
    ( 15 * AVERAGE ( india_inflation_dataset[Milk_Price_INR_Litre] ) ) +
    ( 1 * AVERAGE ( india_inflation_dataset[LPG_Cylinder_INR] ) ),
    0
)
7. RBI Upper Tolerance (>6%) Breach Rate (%):RBI Breach Rate % = 
ROUND (
    DIVIDE (
        CALCULATE (
            COUNTROWS ( india_inflation_dataset ),
            india_inflation_dataset[Headline_Inflation_YoY_Pct] > 6.0
        ),
        COUNTROWS ( india_inflation_dataset ),
        0
    ) * 100,
    1
)
8. Dynamic KPI Conditional Formatting Color:Inflation Status Color = 
SWITCH (
    TRUE (),
    [Avg Headline Inflation %] > 6.0, "#D9534F",   -- Red (Above RBI 6% Upper Limit)
    [Avg Headline Inflation %] >= 4.0, "#F0AD4E",  -- Amber (Within 4%-6% Comfort Zone)
    "#5CB85C"                                      -- Green (Below 4% Target)
)
4. Power BI Dashboard Layout ArchitectureThe Power BI report is designed as a single-page executive dashboard (16:9 canvas):Left Interactive Filter Pane (Slicers): Year (Dim_Calendar[Year]), State, Sector (Urban / Rural), and Region (North, South, East, West).Top KPI Summary Ribbon (5 Card Visuals):Avg Headline Inflation % (7-Year Average: 5.51%)Avg Food Inflation % (7-Year Average: 5.84%)Real Interest Rate % (Repo Rate minus Headline CPI)Purchasing Power of 1000 INR (2019 ₹1,000 reduced to ₹776 by 2025)Monthly Family Basket INR (2025 Average Basket Cost: ₹2,873)Middle Visual Row:Line and Clustered Column Chart: Plots Year on the X-axis, Avg Headline Inflation % and Avg Food Inflation % as bars, and RBI_Repo_Rate_Pct as a line with a horizontal reference line at 6.0% (RBI Upper Tolerance Limit).Clustered Bar Chart / Filled Map: Ranks all 8 Indian states by average headline inflation with conditional color formatting.Bottom Visual Row:Area Chart: Visualizes the erosion of ₹1,000 purchasing power from ₹986.03 (2019) down to ₹776.36 (2025).Matrix Table: Compares Rural vs. Urban monthly essential basket costs and RBI >6% breach rates across states.5. Key Analytical Findings & InsightsAnalytical Dimension2019 Baseline2022 Peak Shock2025 CurrentStrategic TakeawayHeadline CPI Inflation (%)4.43%6.36%4.76%Breached RBI's 6% upper limit in 81.2% of state-sector quarters during 2020 and 2022Food Inflation (%)4.24%7.15%4.86%Strongest driver of headline CPI (r = 0.918 Pearson correlation)RBI Repo Rate (%)5.64%5.26%6.00%250 bps hike (from 4.00% to 6.50% in 2022–2023) cooled inflation by 160 bps by 2025Real Value of ₹1,000 (INR)₹986.03₹837.05₹776.36Cumulative purchasing power eroded by 22.4% over the 7-year periodMonthly Essential Basket (INR)₹2,012.61₹2,652.60₹2,873.36Household expenditure on Rice, Toor Dal, Milk, and LPG rose by 42.8%Regional Disparities: Uttar Pradesh (5.70%) and West Bengal (5.68%) recorded the highest 7-year average headline inflation, whereas Gujarat (5.33%) and Delhi (5.39%) recorded the lowest.Rural vs. Urban Structural Split: Rural areas experienced higher average food inflation (6.08% vs. 5.60% in Urban areas), while Urban areas faced steeper housing inflation (5.05% vs. 3.64% in Rural areas).6. Resume Bullet Points & Interview Preparation GuideA. Resume Project Description (Copy & Paste)India Macroeconomic Inflation & Purchasing Power Analytics | Python, SQL, Power BIAnalyzed 7 years (2019–2025, 448 state-sector records) of CPI inflation, RBI Repo Rate regimes, and essential commodity prices across 8 Indian states (Rural & Urban sectors) using Python (Pandas, NumPy, Seaborn) and SQL.Engineered macroeconomic indicators including Real Interest Rate, Household Essential Basket Index, and Purchasing Power Erosion, revealing a 22.4% decline in the real value of ₹1,000 (down to ₹776) and a 42.8% surge in monthly household grocery and LPG costs between 2019 and 2025.Authored 8 analytical SQL queries utilizing CTEs and Window Functions (LAG, DENSE_RANK, 4-Quarter Moving Average) to track Quarter-over-Quarter inflation momentum and quantify RBI upper-tolerance band (>6%) breaches.Designed an interactive Power BI Dashboard with custom DAX measures to visualize state-wise cost-of-living disparities and demonstrate how RBI's 250 bps Repo Rate hike moderated headline inflation from 6.36% (2022) to 4.76% (2025).B. Common Technical Interview Questions & AnswersQ1: Why did you combine Python, SQL, and Power BI in this project instead of using just one tool?Answer: "Each tool served a distinct layer of the analytics pipeline. I used Python (Pandas & NumPy) for programmatic data cleaning, group-level median imputation, correlation analysis (r = 0.918 between food and headline inflation), and feature engineering (Real_Interest_Rate_Pct and Monthly_Essential_Basket_INR). Next, I structured the data in a relational SQL table and used Window Functions (LAG, DENSE_RANK, and 4-Quarter Moving Average) for time-series benchmarking. Finally, I built a star-schema model with a Dim_Calendar table and DAX measures in Power BI so stakeholders can dynamically slice inflation trends by state, year, and sector."Q2: What was the most actionable insight you uncovered from the data?Answer: "While headline inflation looked similar between Rural (5.48%) and Urban (5.54%) sectors on the surface, decomposing the CPI categories revealed a sharp structural divide: Rural households suffer significantly higher food inflation (6.08% vs. 5.60%), especially during Q3 monsoon quarters, whereas Urban households are primarily squeezed by housing rent inflation (5.05% vs. 3.64%). Furthermore, during 2020–2022, the Real Interest Rate turned negative (-2.25%), meaning standard savings accounts were losing purchasing power until the RBI raised the Repo Rate to 6.50%."
