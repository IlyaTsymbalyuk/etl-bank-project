-- Вспомогательная функция для получения курса валюты на конкретную дату

-- Идея: курс валюты может меняться во времени, поэтому нужно найти запись,
-- где переданная дата попадает в интервал актуальности [DATA_ACTUAL_DATE, DATA_ACTUAL_END_DATE].
-- Если курс не найден, возвращаем 1 (означает, что валюта совпадает с рублем или данные отсутствуют).
CREATE OR REPLACE FUNCTION DS.GET_EXCHANGE_RATE(
    p_currency_rk NUMERIC,
    p_date DATE
)
RETURNS FLOAT AS $$
DECLARE
    v_rate FLOAT;
BEGIN
    SELECT reduced_cource INTO v_rate
    FROM DS.MD_EXCHANGE_RATE_D
    WHERE currency_rk = p_currency_rk
      AND p_date BETWEEN data_actual_date AND COALESCE(data_actual_end_date, '9999-12-31')
    LIMIT 1;
    
    RETURN COALESCE(v_rate, 1);
END;
$$ LANGUAGE plpgsql;

-- Проверка работы функции
SELECT DS.GET_EXCHANGE_RATE(1, '2018-01-15') as test_rate;