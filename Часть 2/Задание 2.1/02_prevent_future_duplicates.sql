-- Задание 2.1: Предотвращение появления дублей в будущем

-- Способ 1: Добавление уникального ограничения (если таблица уже очищена)

-- Проверяем, что дублей нет перед добавлением ограничения
DO $$
DECLARE
    duplicate_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO duplicate_count
    FROM (
        SELECT client_rk, effective_from_date
        FROM dm.client
        GROUP BY client_rk, effective_from_date
        HAVING COUNT(*) > 1
    ) duplicates;
    
    IF duplicate_count > 0 THEN
        RAISE EXCEPTION 'В таблице ещё есть дубли (%). Сначала выполните очистку.', duplicate_count;
    ELSE
        -- Добавляем уникальное ограничение
        ALTER TABLE dm.client 
        ADD CONSTRAINT uk_client_rk_effective_date 
        UNIQUE (client_rk, effective_from_date);
        
        RAISE NOTICE '✅ Уникальное ограничение успешно добавлено';
    END IF;
END;
$$;

-- Способ 2: Использование MERGE для вставки новых данных (защита от дублей)

-- Пример процедуры для безопасной вставки новых записей
CREATE OR REPLACE PROCEDURE dm.safe_insert_client(
    p_client_rk NUMERIC,
    p_effective_from_date DATE,
    p_effective_to_date DATE,
    p_counterparty_type_cd VARCHAR(10),
    p_black_list_flag VARCHAR(1),
    p_client_id VARCHAR(50),
    p_client_name VARCHAR(200)
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Вставляем только если нет существующей записи с таким же ключом
    INSERT INTO dm.client (
        client_rk, effective_from_date, effective_to_date,
        counterparty_type_cd, black_list_flag, client_id, client_name
    )
    VALUES (
        p_client_rk, p_effective_from_date, p_effective_to_date,
        p_counterparty_type_cd, p_black_list_flag, p_client_id, p_client_name
    )
    ON CONFLICT (client_rk, effective_from_date) DO NOTHING;
    
    IF FOUND THEN
        RAISE NOTICE 'Запись для клиента % с датой % добавлена', p_client_rk, p_effective_from_date;
    ELSE
        RAISE NOTICE 'Запись для клиента % с датой % уже существует', p_client_rk, p_effective_from_date;
    END IF;
END;
$$;