---Cargar Datos
CREATE TABLE cc_detail (
    Client_Num INT,
    Card_Category VARCHAR(20),
    Annual_Fees INT,
    Activation_30_Days INT,
    Customer_Acq_Cost INT,
    Week_Start_Date VARCHAR(20),--01-01-2023 DD-MM-YYYY

    Week_Num VARCHAR(20),
    Qtr VARCHAR(10),
    current_year INT,
    Credit_Limit DECIMAL(10,2),
    Total_Revolving_Bal INT,
    Total_Trans_Amt INT,
    Total_Trans_Ct INT,
    Avg_Utilization_Ratio DECIMAL(10,3),
    Use_Chip VARCHAR(10),
    Exp_Type VARCHAR(50),
    Interest_Earned DECIMAL(10,3),
    Delinquent_Acc VARCHAR(5)
);
BULK INSERT cc_detail
FROM 'C:\BulkData\credit_card.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,              -- omitir encabezado
    FIELDTERMINATOR = ',',     -- separador
    ROWTERMINATOR = '\n',      -- separador de líneas
    TABLOCK
);

CREATE TABLE cust_detail (
    Client_Num INT,
    Customer_Age INT,
    Gender VARCHAR(5),
    Dependent_Count INT,
    Education_Level VARCHAR(50),
    Marital_Status VARCHAR(20),
    State_cd VARCHAR(50),
    Zipcode VARCHAR(20),
    Car_Owner VARCHAR(5),
    House_Owner VARCHAR(5),
    Personal_Loan VARCHAR(5),
    Contact VARCHAR(50),
    Customer_Job VARCHAR(50),
    Income INT,
    Cust_Satisfaction_Score INT
);
BULK INSERT cust_detail
FROM 'C:\BulkData\customer.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,              -- omitir encabezado
    FIELDTERMINATOR = ',',     -- separador de campos
    ROWTERMINATOR = '\n',      -- separador de líneas
    TABLOCK
);

-- DIMENSIONES

CREATE TABLE dim_client (
    Client_ID INT PRIMARY KEY,
    Customer_Age INT,
    Gender VARCHAR(5),
    Dependent_Count INT,
    Education_Level VARCHAR(50),
    Marital_Status VARCHAR(20),
    state_cd VARCHAR(50),
    Zipcode VARCHAR(20),
    Car_Owner VARCHAR(5),
    House_Owner VARCHAR(5),
    Personal_loan VARCHAR(5),
    Contact VARCHAR(50),
    Customer_Job VARCHAR(50),
    Income INT,
    Cust_Satisfaction_Score INT
);

CREATE TABLE dim_date (
    Date_ID INT PRIMARY KEY,
    Week_Start_Date DATE,
    Week_Num VARCHAR(20),
    Quarter VARCHAR(10),
    Year INT
);

CREATE TABLE dim_card (
    Card_ID INT IDENTITY(1,1) PRIMARY KEY,
    Card_Category VARCHAR(20)
);

CREATE TABLE dim_transaction_type (
    Trans_Type_ID INT IDENTITY(1,1) PRIMARY KEY,
    Use_Chip VARCHAR(10)
);

CREATE TABLE dim_expense_type (
    Exp_Type_ID INT IDENTITY(1,1) PRIMARY KEY,
    Exp_Type VARCHAR(50)
);

-- TABLA DE HECHOS
CREATE TABLE fact_credit_card_usage (
    Client_ID INT,
    Date_ID INT,
    Card_ID INT,
    Trans_Type_ID INT,
    Exp_Type_ID INT,
    Customer_Acq_Cost INT,
    Credit_Limit DECIMAL(10,2),
    Total_Revolving_Bal INT,
    Total_Trans_Amt INT,
    Total_Trans_Ct INT,
    Avg_Utilization_Ratio DECIMAL(10,3),
    Interest_Earned DECIMAL(10,3),
    Delinquent_Acc VARCHAR(5),
	Annual_Fees INT,
    FOREIGN KEY (Client_ID) REFERENCES dim_client(Client_ID),
    FOREIGN KEY (Date_ID) REFERENCES dim_date(Date_ID),
    FOREIGN KEY (Card_ID) REFERENCES dim_card(Card_ID),
    FOREIGN KEY (Trans_Type_ID) REFERENCES dim_transaction_type(Trans_Type_ID),
    FOREIGN KEY (Exp_Type_ID) REFERENCES dim_expense_type(Exp_Type_ID)
);

---Insertaremos los datos 
-- Cliente
INSERT INTO dim_client
SELECT DISTINCT
    Client_Num, Customer_Age, Gender, Dependent_Count, Education_Level,
    Marital_Status, State_cd, Zipcode, Car_Owner, House_Owner,
    Personal_Loan, Contact, Customer_Job, Income, Cust_Satisfaction_Score
FROM cust_detail;

INSERT INTO dim_date (Date_ID, Week_Start_Date, Week_Num, Quarter, Year)
SELECT DISTINCT
    CONVERT(INT, FORMAT(TRY_CONVERT(DATE, Week_Start_Date, 105), 'yyyyMMdd')) AS Date_ID,
    TRY_CONVERT(DATE, Week_Start_Date, 105) AS Week_Start_Date,
    Week_Num,
    Qtr,
    current_year
FROM cc_detail cd
WHERE NOT EXISTS (
    SELECT 1 FROM dim_date d
    WHERE d.Date_ID = CONVERT(INT, FORMAT(TRY_CONVERT(DATE, cd.Week_Start_Date, 105), 'yyyyMMdd'))
);
-- Categoría de tarjeta
INSERT INTO dim_card (Card_Category)
SELECT DISTINCT Card_Category FROM cc_detail;

-- Tipo de transacción
INSERT INTO dim_transaction_type (Use_Chip)
SELECT DISTINCT Use_Chip FROM cc_detail;

-- Tipo de gasto
INSERT INTO dim_expense_type (Exp_Type)
SELECT DISTINCT (Exp_Type) FROM cc_detail;


---Inseratr los datos a la tabla fact
INSERT INTO fact_credit_card_usage (
    Client_ID,
    Date_ID,
    Card_ID,
    Trans_Type_ID,
    Exp_Type_ID,
    Customer_Acq_Cost,
    Credit_Limit,
    Total_Revolving_Bal,
    Total_Trans_Amt,
    Total_Trans_Ct,
    Avg_Utilization_Ratio,
    Interest_Earned,
    Delinquent_Acc,
	Annual_Fees
)
SELECT
    c.Client_ID,
    d.Date_ID,
    ca.Card_ID,
    tt.Trans_Type_ID,
    et.Exp_Type_ID,
    cd.Customer_Acq_Cost,
    cd.Credit_Limit,
    cd.Total_Revolving_Bal,
    cd.Total_Trans_Amt,
    cd.Total_Trans_Ct,
    cd.Avg_Utilization_Ratio,
    cd.Interest_Earned,
    cd.Delinquent_Acc,
	cd.Annual_Fees
FROM cc_detail cd
JOIN dim_client c ON cd.Client_Num = c.Client_ID
JOIN dim_date d ON CONVERT(INT, FORMAT(TRY_CONVERT(DATE, cd.Week_Start_Date, 105), 'yyyyMMdd')) = d.Date_ID
JOIN dim_card ca ON cd.Card_Category = ca.Card_Category
JOIN dim_transaction_type tt ON cd.Use_Chip = tt.Use_Chip
JOIN dim_expense_type et ON cd.Exp_Type = et.Exp_Type;
----Puedes ejecutar para revisar
select* from fact_credit_card_usage
