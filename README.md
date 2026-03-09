# 🎵 Chinook-Music-Database
Chinook Music Database Analysis – Comprehensive analysis of the Chinook Music Database using SQL and Excel. Includes data cleaning, sales trends, artist performance, customer behavior insights, product affinity, and churn segmentation to support data-driven business decisions.

### 📂 Project Database
You can view the full IT Ticket Analysis project and dashboard here:

[Access Chinook Music Database (Excel)](https://drive.google.com/file/d/1nGhcd_eeaIiKb8_UPBykxH1_OxMupi5M/view)

# 📋 Project Overview
This repository contains a comprehensive data analysis project based on the Chinook Music Database (a sample database representing a digital media store). The project involves querying, cleaning, and analyzing sales, customer, and inventory data using MySQL to derive actionable business insights and strategic recommendations.

# 🚀 Key Objectives

- **Data Integrity:** Performed thorough audit of all 11 database tables to detect missing values and duplicate records.
- **Customer Behavior:** Analyzed geographic purchasing trends, customer demographics, and loyalty segments (long-term vs. new customers).
- **Sales Performance:** Identified top-selling tracks, artists, and genres within the USA and global markets.
- **Strategic Growth:** Developed data-driven recommendations for advertising, product bundling, and retention strategies to mitigate churn.

# 🛠 Tech Stack & Skills

- **Database Management:** MySQL (MySQL Workbench).
- **Advanced SQL:**
- **Advanced SQL:**
  - Window Functions: `RANK()`, `DENSE_RANK()`, `ROW_NUMBER()` for performance ranking
  - Data Cleaning: `COALESCE`, NULL handling, and set-based duplicates checks
  - Complex Joins & Aggregation: Multi-table joins across invoice, track, album, artist, and genre entities
  - CTE (Common Table Expressions): Implemented for cleaner, readable query logic
- **Reporting:** Analytical reporting on churn rates, genre diversity, and purchase frequency

#🔑 Key Insights & Findings
- **Data Quality:** The dataset demonstrated high integrity; missing values were confined to optional fields, and no record-level duplicates were found.
- **Market Dynamics:** Rock is the dominant genre globally. Analysis highlighted specific niche opportunities in countries like Ireland and the Czech Republic.
- **Retention Strategy:** Customer spending behavior is consistent across long-term and new user segments, indicating strong onboarding potential.
- **Cross-Selling:** Identified frequent co-purchase patterns (e.g., Rock ↔ Metal) to support the design of effective recommendation engines and promotional bundles.

