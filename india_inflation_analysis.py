"""
===============================================================================
PROJECT TITLE : India Inflation, Commodity Prices & Purchasing Power Analysis
AUTHOR        : Varsha Devi (Data Analytics Portfolio Project)
TOOLS USED    : Python (Pandas, NumPy, Matplotlib, Seaborn), SQL, Power BI
DESCRIPTION   : End-to-End Data Cleaning, Feature Engineering, Exploratory Data
                Analysis (EDA), RBI Monetary Policy Impact & Trend Analysis.
===============================================================================
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

# Set visual style for plots
plt.style.use('seaborn-v0_8-whitegrid')
pd.set_option('display.max_columns', None)
pd.set_option('display.width', 1000)


# ==============================================================================
# STEP 1: DATA LOADING & INITIAL INSPECTION (தரவை ஏற்றுதல் மற்றும் பரிசோதித்தல்)
# ==============================================================================
def load_and_inspect_data(filepath: str) -> pd.DataFrame:
    print("=" * 75)
    print("STEP 1: LOADING & INSPECTING INDIA INFLATION DATASET")
    print("=" * 75)
    df = pd.read_csv(filepath)
    print(f"Dataset Shape: {df.shape[0]} rows, {df.shape[1]} columns\n")
    print("Column Data Types & Non-Null Counts:")
    print(df.info())
    print("\nFirst 5 Records:")
    print(df.head())
    return df


# ==============================================================================
# STEP 2: DATA CLEANING & PREPROCESSING (தரவு சுத்தம் செய்தல்)
# ==============================================================================
def clean_and_preprocess(df: pd.DataFrame) -> pd.DataFrame:
    print("\n" + "=" * 75)
    print("STEP 2: DATA CLEANING & PREPROCESSING")
    print("=" * 75)
    df_clean = df.copy()

    # 1. Convert Observation_Date to datetime format
    df_clean['Observation_Date'] = pd.to_datetime(df_clean['Observation_Date'])

    # 2. Check and remove duplicate records if any
    duplicates = df_clean.duplicated(subset=['Year', 'Quarter', 'State', 'Sector']).sum()
    print(f"Duplicate rows detected: {duplicates}")
    df_clean = df_clean.drop_duplicates(subset=['Year', 'Quarter', 'State', 'Sector'])

    # 3. Handle missing values in numeric columns using State-Sector median imputation
    numeric_cols = df_clean.select_dtypes(include=[np.number]).columns
    missing_before = df_clean[numeric_cols].isnull().sum().sum()
    print(f"Missing numeric values before cleaning: {missing_before}")

    for col in numeric_cols:
        if df_clean[col].isnull().sum() > 0:
            df_clean[col] = df_clean.groupby(['State', 'Sector'])[col].transform(
                lambda x: x.fillna(x.median())
            )

    # Sort chronologically for time-series operations
    df_clean = df_clean.sort_values(by=['State', 'Sector', 'Observation_Date']).reset_index(drop=True)
    print("Data cleaning completed successfully.")
    return df_clean


# ==============================================================================
# STEP 3: FEATURE ENGINEERING (புதிய பகுப்பாய்வு மாறிகளை உருவாக்குதல்)
# ==============================================================================
def engineer_features(df: pd.DataFrame) -> pd.DataFrame:
    print("\n" + "=" * 75)
    print("STEP 3: MACROECONOMIC FEATURE ENGINEERING")
    print("=" * 75)
    df_feat = df.copy()

    # 1. Real Interest Rate (%) = RBI Repo Rate - Headline Inflation
    # Positive Real Rate encourages savings; Negative erodes savings value
    df_feat['Real_Interest_Rate_Pct'] = (
        df_feat['RBI_Repo_Rate_Pct'] - df_feat['Headline_Inflation_YoY_Pct']
    ).round(2)

    # 2. Essential Household Food Basket Cost (INR)
    # Monthly family consumption weight: 10 Kg Rice + 3 Kg Toor Dal + 15 L Milk + 1 LPG Cylinder
    df_feat['Monthly_Essential_Basket_INR'] = (
        10 * df_feat['Rice_Price_INR_Kg'] +
        3 * df_feat['Toor_Dal_Price_INR_Kg'] +
        15 * df_feat['Milk_Price_INR_Litre'] +
        1 * df_feat['LPG_Cylinder_INR']
    ).round(2)

    # 3. Purchasing Power Erosion (%) relative to Rs. 1,000 in 2019
    df_feat['Purchasing_Power_Loss_Pct'] = (
        ((1000.0 - df_feat['Purchasing_Power_of_1000_INR']) / 1000.0) * 100
    ).round(2)

    # 4. Quarter-over-Quarter (QoQ) Inflation Change using groupby shift
    df_feat['QoQ_Inflation_Delta'] = (
        df_feat.groupby(['State', 'Sector'])['Headline_Inflation_YoY_Pct']
        .diff()
        .fillna(0.0)
        .round(2)
    )

    # 5. RBI Upper Tolerance Breach Flag (1 if > 6.0%, else 0)
    df_feat['RBI_Breach_Flag'] = np.where(df_feat['Headline_Inflation_YoY_Pct'] > 6.0, 1, 0)

    print("Engineered Features Summary:")
    print(
        df_feat[[
            'Year', 'Quarter', 'State', 'Sector',
            'Real_Interest_Rate_Pct', 'Monthly_Essential_Basket_INR',
            'Purchasing_Power_Loss_Pct', 'RBI_Breach_Flag'
        ]].head(8)
    )
    return df_feat


# ==============================================================================
# STEP 4: EXPLORATORY DATA ANALYSIS (EDA) & KEY INSIGHTS
# ==============================================================================
def perform_eda(df: pd.DataFrame) -> None:
    print("\n" + "=" * 75)
    print("STEP 4: EXPLORATORY DATA ANALYSIS (EDA) & PORTFOLIO INSIGHTS")
    print("=" * 75)

    # Insight 1: Annual Macro Trend (Headline vs Food vs Fuel Inflation & Repo Rate)
    annual_summary = df.groupby('Year').agg(
        Avg_Headline_CPI=('Headline_Inflation_YoY_Pct', 'mean'),
        Avg_Food_Inflation=('Food_Inflation_YoY_Pct', 'mean'),
        Avg_Fuel_Inflation=('Fuel_Inflation_YoY_Pct', 'mean'),
        Avg_Repo_Rate=('RBI_Repo_Rate_Pct', 'mean'),
        Avg_Purchasing_Power_of_1000=('Purchasing_Power_of_1000_INR', 'mean'),
        Avg_Essential_Basket_INR=('Monthly_Essential_Basket_INR', 'mean'),
        RBI_Breach_Rate_Pct=('RBI_Breach_Flag', lambda x: round(x.mean() * 100, 1))
    ).round(2)

    print("\n--- 1. Annual Macroeconomic & Purchasing Power Trend (2019-2025) ---")
    print(annual_summary)

    # Insight 2: State-wise Inflation Ranking
    state_summary = df.groupby(['State', 'Region']).agg(
        Avg_Headline_Inflation=('Headline_Inflation_YoY_Pct', 'mean'),
        Avg_Food_Inflation=('Food_Inflation_YoY_Pct', 'mean'),
        Avg_Petrol_Price_INR=('Petrol_Price_INR_Litre', 'mean'),
        Breach_Quarters_Count=('RBI_Breach_Flag', 'sum')
    ).round(2).sort_values(by='Avg_Headline_Inflation', ascending=False)

    print("\n--- 2. State-Wise Inflation & Commodity Price Ranking ---")
    print(state_summary)

    # Insight 3: Rural vs Urban Sector Comparison
    sector_summary = df.groupby('Sector').agg(
        Avg_Headline_Inflation=('Headline_Inflation_YoY_Pct', 'mean'),
        Avg_Food_Inflation=('Food_Inflation_YoY_Pct', 'mean'),
        Avg_Housing_Inflation=('Housing_Inflation_YoY_Pct', 'mean'),
        Avg_Healthcare_Inflation=('Healthcare_Inflation_YoY_Pct', 'mean')
    ).round(2)

    print("\n--- 3. Rural vs Urban Sector Inflation Comparison ---")
    print(sector_summary)

    # Insight 4: Correlation Matrix (How Fuel, Food & Repo Rate relate to Headline CPI)
    corr_cols = [
        'Headline_Inflation_YoY_Pct',
        'Food_Inflation_YoY_Pct',
        'Fuel_Inflation_YoY_Pct',
        'Housing_Inflation_YoY_Pct',
        'RBI_Repo_Rate_Pct',
        'Petrol_Price_INR_Litre'
    ]
    corr_matrix = df[corr_cols].corr().round(3)
    print("\n--- 4. Pearson Correlation Matrix ---")
    print(corr_matrix)


# ==============================================================================
# STEP 5: VISUALIZATION GENERATION (சிறப்பு வரைபடங்களை உருவாக்குதல்)
# ==============================================================================
def generate_portfolio_charts(df: pd.DataFrame, output_chart_path: str) -> None:
    print("\n" + "=" * 75)
    print("STEP 5: GENERATING PORTFOLIO VISUALIZATION DASHBOARD")
    print("=" * 75)

    fig, axes = plt.subplots(2, 2, figsize=(15, 10))
    fig.suptitle(
        "India Inflation & Purchasing Power Analytics (2019-2025) | Portfolio: Varsha Devi",
        fontsize=15, fontweight='bold', y=0.98
    )

    # Chart 1: Headline Inflation vs RBI Repo Rate Over Time
    yearly = df.groupby('Year', as_index=False).agg({
        'Headline_Inflation_YoY_Pct': 'mean',
        'Food_Inflation_YoY_Pct': 'mean',
        'RBI_Repo_Rate_Pct': 'mean'
    })
    ax1 = axes[0, 0]
    ax1.plot(yearly['Year'], yearly['Headline_Inflation_YoY_Pct'], marker='o', linewidth=2.5, label='Headline CPI (%)', color='#d95f02')
    ax1.plot(yearly['Year'], yearly['Food_Inflation_YoY_Pct'], marker='s', linestyle='--', linewidth=2.0, label='Food Inflation (%)', color='#e7298a')
    ax1.plot(yearly['Year'], yearly['RBI_Repo_Rate_Pct'], marker='^', linewidth=2.5, label='RBI Repo Rate (%)', color='#1b9e77')
    ax1.axhline(6.0, color='red', linestyle=':', alpha=0.7, label='RBI Upper Limit (6%)')
    ax1.set_title("1. Headline CPI, Food Inflation & RBI Repo Rate Trend", fontweight='bold')
    ax1.set_xlabel("Year")
    ax1.set_ylabel("Rate (%)")
    ax1.legend(loc='best', fontsize=9)

    # Chart 2: Erosion of Purchasing Power of Rs. 1,000 (2019 Base)
    pp_yearly = df.groupby('Year', as_index=False)['Purchasing_Power_of_1000_INR'].mean()
    ax2 = axes[0, 1]
    bars = ax2.bar(pp_yearly['Year'].astype(str), pp_yearly['Purchasing_Power_of_1000_INR'], color='#386cb0', width=0.55)
    ax2.set_title("2. Real Value of Rs. 1,000 Over Time (Base Year = 2019)", fontweight='bold')
    ax2.set_xlabel("Year")
    ax2.set_ylabel("Real Purchasing Power (INR)")
    ax2.set_ylim(0, 1150)
    for bar in bars:
        height = bar.get_height()
        ax2.annotate(f"Rs.{height:.0f}", xy=(bar.get_x() + bar.get_width() / 2, height),
                     xytext=(0, 4), textcoords="offset points", ha='center', fontsize=9, fontweight='bold')

    # Chart 3: State-wise Average Inflation Comparison
    state_avg = df.groupby('State', as_index=False)['Headline_Inflation_YoY_Pct'].mean().sort_values('Headline_Inflation_YoY_Pct')
    ax3 = axes[1, 0]
    ax3.barh(state_avg['State'], state_avg['Headline_Inflation_YoY_Pct'], color='#7570b3')
    ax3.axvline(6.0, color='red', linestyle='--', alpha=0.7, label='6% RBI Threshold')
    ax3.set_title("3. Average Headline Inflation by Indian State (%)", fontweight='bold')
    ax3.set_xlabel("Headline Inflation YoY (%)")
    ax3.legend(loc='lower right', fontsize=9)

    # Chart 4: Monthly Household Essential Basket Cost (Rural vs Urban)
    basket_trend = df.groupby(['Year', 'Sector'], as_index=False)['Monthly_Essential_Basket_INR'].mean()
    ax4 = axes[1, 1]
    sns.lineplot(
        data=basket_trend, x='Year', y='Monthly_Essential_Basket_INR',
        hue='Sector', marker='o', linewidth=2.5, palette=['#1b9e77', '#d95f02'], ax=ax4
    )
    ax4.set_title("4. Household Essential Basket Cost (INR): Urban vs Rural", fontweight='bold')
    ax4.set_xlabel("Year")
    ax4.set_ylabel("Monthly Basket Cost (INR)")

    plt.tight_layout(rect=[0, 0, 1, 0.95])
    plt.savefig(output_chart_path, dpi=150)
    plt.close()
    print(f"Summary chart saved to: {output_chart_path}")


if __name__ == "__main__":
    DATASET_PATH = "india_inflation_dataset.csv"
    CHART_OUTPUT = "eda_summary_chart.png"

    import os
    if not os.path.exists(DATASET_PATH):
        DATASET_PATH = "/working_dir/c_19636c380314b083/artifacts/file_generation/ttl=63d/output/india_inflation_dataset.csv"
        CHART_OUTPUT = "/working_dir/c_19636c380314b083/artifacts/file_generation/ttl=63d/intermediate/eda_summary_chart.png"

    raw_df = load_and_inspect_data(DATASET_PATH)
    clean_df = clean_and_preprocess(raw_df)
    enriched_df = engineer_features(clean_df)
    perform_eda(enriched_df)
    generate_portfolio_charts(enriched_df, CHART_OUTPUT)