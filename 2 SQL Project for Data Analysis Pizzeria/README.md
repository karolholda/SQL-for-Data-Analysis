# 🍕 PizzeriaDB: Database for an Pizzeria Restaurant

The database project focused on analyzing key metrics and operational efficiencies for a pizza business. The primary objectives were to calculate the total quantity and cost of ingredients, determine the cost of each pizza, evaluate the remaining stock levels for each ingredient, and identify items that required reordering based on inventory levels.

The initial phase involved integrating multiple tables using LEFT JOIN operations. Specifically, the address, orders, and item tables were connected to facilitate a comprehensive dataset for analyzing the quantities of pizzas ordered. By joining the orders and item tables on the item_id field, I calculated the total quantity of each type of pizza ordered across all transactions.

To streamline data analysis, subqueries were utilized to isolate relevant columns and simplify subsequent operations. These subqueries formed the foundation for determining the ingredient requirements for all orders. The analysis culminated in the creation of the ingredient_cost column, which provided the total cost of ingredients required to fulfill all orders.

For improved data manipulation and readability, the subqueries were later replaced with Common Table Expressions (CTEs). This adjustment enabled simultaneous operations on multiple datasets, allowing for the precise calculation of the total weight of all ingredients used in pizza preparation. Following this, inventory amounts were assessed, leading to the calculation of remaining stock levels for each ingredient.

The project also incorporated an analysis of employee work hours and associated labor costs. Using the TIMEDIFF() function, work durations were converted into minutes, which were subsequently divided by 60 to obtain total hours worked. This data was then used to calculate the total labor costs for individual employees.

Through these comprehensive steps, the project delivered actionable insights into ingredient usage, inventory management, and labor costs, supporting strategic decision-making and operational efficiency.
---

## 📊 Project Overview

![Dashboard](https://github.com/karolholda/SQL-for-Data-Analysis/blob/main/2%20SQL%20Project%20for%20Data%20Analysis%20Pizzeria/diagram.jpg)


### 🎯 Objectives
- 🛠️ Build a robust database schema to support an e-commerce platform.
- 🔥 Efficiently manage restaurant equipment inventory and product details.
- 👤 Enable user management, including workers roles
- 📦 Process and store customer orders and their statuses.
- 📈 Provide a foundation for analyzing sales and inventory data.

---

## ❓ Key Features
- **Database Schema Design**: Includes tables for products, users, orders, and inventory relationships.
- **User Management**: Supports different roles, such as customers and administrators.
- **Order Processing**: Tracks order details, statuses, and relationships with users and products.
- **Inventory Management**: Monitors stock levels and updates dynamically.
- **Data Integration**: Includes test data for validating the database structure.

---

## 🛠️ Tools and Technologies Used
- **SQL**: Core technology for schema definition and data manipulation.
