-- Задание 1.2: Полный расчёт и проверка результатов

-- 1. Очищаем старые данные (для перезапуска)
TRUNCATE TABLE DM.DM_ACCOUNT_TURNOVER_F;
TRUNCATE TABLE DM.DM_ACCOUNT_BALANCE_F;

-- 2. Инициализация остатков на 31.12.2017
DELETE FROM DM.DM_ACCOUNT_BALANCE_F WHERE ON_DATE = '2017-12-31';

INSERT INTO DM.DM_ACCOUNT_BALANCE_F (ON_DATE, ACCOUNT_RK, BALANCE_OUT, BALANCE_OUT_RUB)
SELECT 
    ON_DATE,
    ACCOUNT_RK,
    BALANCE_OUT,
    BALANCE_OUT
FROM DS.FT_BALANCE_F 
WHERE ON_DATE = '2017-12-31';

-- 3. Запуск расчёта за весь январь 2018
DO $$
DECLARE
    d DATE;
    start_date DATE := '2018-01-01';
    end_date DATE := '2018-01-31';
BEGIN
    FOR d IN SELECT generate_series(start_date, end_date, '1 day'::interval)::DATE
    LOOP
        CALL DS.FILL_ACCOUNT_TURNOVER_F(d);
        CALL DS.FILL_ACCOUNT_BALANCE_F(d);
    END LOOP;
END;
$$;

-- 4. Проверка витрины оборотов: сколько записей по дням
SELECT 
    ON_DATE, 
    COUNT(*) as records_count,
    SUM(CREDIT_AMOUNT) as total_credit,
    SUM(DEBET_AMOUNT) as total_debet
FROM DM.DM_ACCOUNT_TURNOVER_F
WHERE ON_DATE BETWEEN '2018-01-01' AND '2018-01-31'
GROUP BY ON_DATE
ORDER BY ON_DATE;

-- 5. Проверка витрины остатков: сколько записей по дням
SELECT 
    ON_DATE, 
    COUNT(*) as records_count,
    SUM(BALANCE_OUT) as total_balance
FROM DM.DM_ACCOUNT_BALANCE_F
WHERE ON_DATE BETWEEN '2018-01-01' AND '2018-01-31'
GROUP BY ON_DATE
ORDER BY ON_DATE;

-- 6. Пример данных из витрины оборотов (первые 10 записей за 15 января)
SELECT * FROM DM.DM_ACCOUNT_TURNOVER_F 
WHERE ON_DATE = '2018-01-15' 
LIMIT 10;

-- 7. Пример данных из витрины остатков (первые 10 записей за 15 января)
SELECT * FROM DM.DM_ACCOUNT_BALANCE_F 
WHERE ON_DATE = '2018-01-15' 
LIMIT 10;