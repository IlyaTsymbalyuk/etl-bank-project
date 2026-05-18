# etl_full.py
# Импортируем необходимые библиотеки
import psycopg2          # Для подключения к PostgreSQL
import pandas as pd      # Для чтения CSV-файлов
import time              # Для паузы 5 секунд
from datetime import datetime  # Для логирования времени
from config import DB_CONFIG, CSV_PATHS  # Настройки из config.py

# =================================
# ФУНКЦИЯ ПОДКЛЮЧЕНИЯ К БАЗЕ ДАННЫХ
# =================================
def get_connection():
    """Создание подключения к БД"""
    # Формируем строку подключения из параметров в config.py
    conn_string = f"host='{DB_CONFIG['host']}' port='{DB_CONFIG['port']}' dbname='{DB_CONFIG['database']}' user='{DB_CONFIG['user']}' password='{DB_CONFIG['password']}'"
    return psycopg2.connect(conn_string)

# ===================
# ФУНКЦИЯ ЛОГИРОВАНИЯ
# ===================
def log_operation(conn, table_name, operation_type, start_time, end_time, rows_affected, status, error_message=None):
    """
    Записывает информацию о каждой операции в таблицу LOGS.ETL_LOG
    - table_name: имя таблицы
    - operation_type: тип операции (LOAD, FULL_LOAD)
    - start_time, end_time: время начала и конца
    - rows_affected: количество загруженных записей
    - status: SUCCESS или ERROR
    - error_message: текст ошибки (если есть)
    """
    cur = conn.cursor()
    query = """
        INSERT INTO LOGS.ETL_LOG 
        (table_name, operation_type, start_time, end_time, rows_affected, status, error_message)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
    """
    cur.execute(query, (table_name, operation_type, start_time, end_time, rows_affected, status, error_message))
    conn.commit()  # Сохраняем запись в логе
    cur.close()

# =======================================
# ЗАГРУЗКА ТАБЛИЦЫ FT_BALANCE_F (ОСТАТКИ)
# =======================================
def load_ft_balance_f(conn, file_path):
    """
    Загрузка ft_balance_f.csv
    Особенность: дата в формате DD.MM.YYYY
    Режим: UPSERT (ON CONFLICT DO UPDATE) по (ON_DATE, ACCOUNT_RK)
    """
    print("  Загрузка ft_balance_f...")
    df = pd.read_csv(file_path, sep=';')
    # Важно! Преобразование даты из формата ДД.ММ.ГГГГ
    df['ON_DATE'] = pd.to_datetime(df['ON_DATE'], format='%d.%m.%Y')
    
    cur = conn.cursor()
    for _, row in df.iterrows():
        # UPSERT: если запись существует — обновляем, если нет — вставляем
        cur.execute("""
            INSERT INTO DS.FT_BALANCE_F (ON_DATE, ACCOUNT_RK, CURRENCY_RK, BALANCE_OUT)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (ON_DATE, ACCOUNT_RK) DO UPDATE SET
                CURRENCY_RK = EXCLUDED.CURRENCY_RK,
                BALANCE_OUT = EXCLUDED.BALANCE_OUT
        """, (row['ON_DATE'], row['ACCOUNT_RK'], row['CURRENCY_RK'], row['BALANCE_OUT']))
    conn.commit()  # Фиксируем все изменения
    cur.close()
    return len(df)  # Возвращаем количество записей для лога

# ========================================
# ЗАГРУЗКА ТАБЛИЦЫ FT_POSTING_F (ПРОВОДКИ)
# ========================================
def load_ft_posting_f(conn, file_path):
    """
    Загрузка ft_posting_f.csv
    Особенность: дата в формате DD-MM-YYYY
    Режим: полная перезагрузка (TRUNCATE + INSERT), так как PK нет
    """
    print("  Загрузка ft_posting_f...")
    df = pd.read_csv(file_path, sep=';')
    # Важно! Преобразование даты из формата ДД-ММ-ГГГГ
    df['OPER_DATE'] = pd.to_datetime(df['OPER_DATE'], format='%d-%m-%Y')
    
    cur = conn.cursor()
    # Очищаем таблицу перед загрузкой (полная перезагрузка)
    cur.execute("TRUNCATE TABLE DS.FT_POSTING_F;")
    for _, row in df.iterrows():
        cur.execute("""
            INSERT INTO DS.FT_POSTING_F (OPER_DATE, CREDIT_ACCOUNT_RK, DEBET_ACCOUNT_RK, CREDIT_AMOUNT, DEBET_AMOUNT)
            VALUES (%s, %s, %s, %s, %s)
        """, (row['OPER_DATE'], row['CREDIT_ACCOUNT_RK'], row['DEBET_ACCOUNT_RK'], 
              row['CREDIT_AMOUNT'], row['DEBET_AMOUNT']))
    conn.commit()
    cur.close()
    return len(df)

# =================================================
# ЗАГРУЗКА ТАБЛИЦЫ MD_ACCOUNT_D (СПРАВОЧНИК СЧЕТОВ)
# =================================================
def load_md_account_d(conn, file_path):
    """
    Загрузка md_account_d.csv
    Особенность: дата в формате YYYY-MM-DD (уже готовый формат)
    Режим: UPSERT по (DATA_ACTUAL_DATE, ACCOUNT_RK)
    """
    print("  Загрузка md_account_d...")
    df = pd.read_csv(file_path, sep=';')
    df['DATA_ACTUAL_DATE'] = pd.to_datetime(df['DATA_ACTUAL_DATE'])
    df['DATA_ACTUAL_END_DATE'] = pd.to_datetime(df['DATA_ACTUAL_END_DATE'])
    
    cur = conn.cursor()
    for _, row in df.iterrows():
        cur.execute("""
            INSERT INTO DS.MD_ACCOUNT_D (DATA_ACTUAL_DATE, DATA_ACTUAL_END_DATE, ACCOUNT_RK, ACCOUNT_NUMBER, CHAR_TYPE, CURRENCY_RK, CURRENCY_CODE)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (DATA_ACTUAL_DATE, ACCOUNT_RK) DO UPDATE SET
                DATA_ACTUAL_END_DATE = EXCLUDED.DATA_ACTUAL_END_DATE,
                ACCOUNT_NUMBER = EXCLUDED.ACCOUNT_NUMBER,
                CHAR_TYPE = EXCLUDED.CHAR_TYPE,
                CURRENCY_RK = EXCLUDED.CURRENCY_RK,
                CURRENCY_CODE = EXCLUDED.CURRENCY_CODE
        """, (row['DATA_ACTUAL_DATE'], row['DATA_ACTUAL_END_DATE'], row['ACCOUNT_RK'], 
              row['ACCOUNT_NUMBER'], row['CHAR_TYPE'], row['CURRENCY_RK'], row['CURRENCY_CODE']))
    conn.commit()
    cur.close()
    return len(df)

# =================================================
# ЗАГРУЗКА ТАБЛИЦЫ MD_CURRENCY_D (СПРАВОЧНИК ВАЛЮТ)
# =================================================
def load_md_currency_d(conn, file_path):
    """
    Загрузка md_currency_d.csv
    Особенность: автоопределение кодировки (cp1251, latin1, utf-8)
    Режим: UPSERT по (CURRENCY_RK, DATA_ACTUAL_DATE)
    """
    print("  Загрузка md_currency_d...")
    
    # Пробуем разные кодировки, так как файл может быть в Windows-1251
    for enc in ['cp1251', 'latin1', 'utf-8', 'cp866']:
        try:
            df = pd.read_csv(file_path, sep=';', encoding=enc)
            print(f"    Кодировка {enc} сработала")
            break
        except UnicodeDecodeError:
            continue
    else:
        raise Exception("Не удалось прочитать файл")
    
    df['DATA_ACTUAL_DATE'] = pd.to_datetime(df['DATA_ACTUAL_DATE'])
    df['DATA_ACTUAL_END_DATE'] = pd.to_datetime(df['DATA_ACTUAL_END_DATE'])
    
    cur = conn.cursor()
    for _, row in df.iterrows():
        cur.execute("""
            INSERT INTO DS.MD_CURRENCY_D (CURRENCY_RK, DATA_ACTUAL_DATE, DATA_ACTUAL_END_DATE, CURRENCY_CODE, CODE_ISO_CHAR)
            VALUES (%s, %s, %s, %s, %s)
            ON CONFLICT (CURRENCY_RK, DATA_ACTUAL_DATE) DO UPDATE SET
                DATA_ACTUAL_END_DATE = EXCLUDED.DATA_ACTUAL_END_DATE,
                CURRENCY_CODE = EXCLUDED.CURRENCY_CODE,
                CODE_ISO_CHAR = EXCLUDED.CODE_ISO_CHAR
        """, (row['CURRENCY_RK'], row['DATA_ACTUAL_DATE'], row['DATA_ACTUAL_END_DATE'], 
              row['CURRENCY_CODE'], row['CODE_ISO_CHAR']))
    conn.commit()
    cur.close()
    return len(df)

# =================================================
# ЗАГРУЗКА ТАБЛИЦЫ MD_EXCHANGE_RATE_D (КУРСЫ ВАЛЮТ)
# =================================================
def load_md_exchange_rate_d(conn, file_path):
    """
    Загрузка md_exchange_rate_d.csv
    Режим: UPSERT по (DATA_ACTUAL_DATE, CURRENCY_RK)
    """
    print("  Загрузка md_exchange_rate_d...")
    df = pd.read_csv(file_path, sep=';')
    df['DATA_ACTUAL_DATE'] = pd.to_datetime(df['DATA_ACTUAL_DATE'])
    df['DATA_ACTUAL_END_DATE'] = pd.to_datetime(df['DATA_ACTUAL_END_DATE'])
    
    cur = conn.cursor()
    for _, row in df.iterrows():
        cur.execute("""
            INSERT INTO DS.MD_EXCHANGE_RATE_D (DATA_ACTUAL_DATE, DATA_ACTUAL_END_DATE, CURRENCY_RK, REDUCED_COURCE, CODE_ISO_NUM)
            VALUES (%s, %s, %s, %s, %s)
            ON CONFLICT (DATA_ACTUAL_DATE, CURRENCY_RK) DO UPDATE SET
                DATA_ACTUAL_END_DATE = EXCLUDED.DATA_ACTUAL_END_DATE,
                REDUCED_COURCE = EXCLUDED.REDUCED_COURCE,
                CODE_ISO_NUM = EXCLUDED.CODE_ISO_NUM
        """, (row['DATA_ACTUAL_DATE'], row['DATA_ACTUAL_END_DATE'], row['CURRENCY_RK'], 
              row['REDUCED_COURCE'], row['CODE_ISO_NUM']))
    conn.commit()
    cur.close()
    return len(df)

# =======================================================
# ЗАГРУЗКА ТАБЛИЦЫ MD_LEDGER_ACCOUNT_S (БАЛАНСОВЫЕ СЧЕТА)
# =======================================================
def load_md_ledger_account_s(conn, file_path):
    """
    Загрузка md_ledger_account_s.csv
    Особенность: загружаем только те колонки, которые есть в CSV
    Режим: UPSERT по (LEDGER_ACCOUNT, START_DATE)
    """
    print("  Загрузка md_ledger_account_s...")
    df = pd.read_csv(file_path, sep=';', encoding='utf-8')
    
    # Выводим колонки для информации (полезно при отладке)
    print(f"    Колонки в файле: {list(df.columns)}")
    
    df['START_DATE'] = pd.to_datetime(df['START_DATE'])
    df['END_DATE'] = pd.to_datetime(df['END_DATE'])
    
    cur = conn.cursor()
    for _, row in df.iterrows():
        cur.execute("""
            INSERT INTO DS.MD_LEDGER_ACCOUNT_S 
            (CHAPTER, CHAPTER_NAME, SECTION_NUMBER, SECTION_NAME, SUBSECTION_NAME, 
             LEDGER1_ACCOUNT, LEDGER1_ACCOUNT_NAME, LEDGER_ACCOUNT, LEDGER_ACCOUNT_NAME, 
             CHARACTERISTIC, START_DATE, END_DATE)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (LEDGER_ACCOUNT, START_DATE) DO UPDATE SET
                CHAPTER = EXCLUDED.CHAPTER,
                CHAPTER_NAME = EXCLUDED.CHAPTER_NAME,
                END_DATE = EXCLUDED.END_DATE
        """, (
            row['CHAPTER'], row['CHAPTER_NAME'], row['SECTION_NUMBER'], row['SECTION_NAME'],
            row['SUBSECTION_NAME'], row['LEDGER1_ACCOUNT'], row['LEDGER1_ACCOUNT_NAME'],
            row['LEDGER_ACCOUNT'], row['LEDGER_ACCOUNT_NAME'], row['CHARACTERISTIC'],
            row['START_DATE'], row['END_DATE']
        ))
    conn.commit()
    cur.close()
    return len(df)

# ===========================================
# ОСНОВНАЯ ФУНКЦИЯ (ОРКЕСТРАТОР ETL-ПРОЦЕССА)
# ===========================================
def main():
    """Основной ETL-процесс"""
    print("=" * 60)
    print("НАЧАЛО ETL-ПРОЦЕССА")
    print("=" * 60)
    start_time = datetime.now()  # Засекаем время начала
    
    # Шаг 1: Подключение к БД
    conn = get_connection()
    print(f"✅ Подключено к БД: {DB_CONFIG['database']}")
    
    # Пауза 5 секунд (по заданию, чтобы видеть разницу во времени)
    print("\n⏳ Пауза 5 секунд (эмуляция долгого процесса)...")
    time.sleep(5)
    
    # Шаг 2: Загрузка данных (последовательно для каждой таблицы)
    print("\n--- ЗАГРУЗКА ДАННЫХ ---")
    
    # Список таблиц и соответствующих функций загрузки
    tables_loaders = [
        ('ft_balance_f', load_ft_balance_f),
        ('ft_posting_f', load_ft_posting_f),
        ('md_account_d', load_md_account_d),
        ('md_currency_d', load_md_currency_d),
        ('md_exchange_rate_d', load_md_exchange_rate_d),
        ('md_ledger_account_s', load_md_ledger_account_s)
    ]
    
    # Загружаем каждую таблицу
    for table_name, loader in tables_loaders:
        table_start = datetime.now()
        try:
            file_path = CSV_PATHS.get(table_name)
            if not file_path:
                print(f"  ⚠️ Пропуск {table_name}: путь не указан")
                continue
            rows = loader(conn, file_path)  # Вызываем функцию загрузки
            table_end = datetime.now()
            # Записываем успешный лог
            log_operation(conn, table_name, 'LOAD', table_start, table_end, rows, 'SUCCESS')
            print(f"  ✅ {table_name}: загружено {rows} записей")
        except Exception as e:
            table_end = datetime.now()
            # Записываем лог с ошибкой
            log_operation(conn, table_name, 'LOAD', table_start, table_end, 0, 'ERROR', str(e))
            print(f"  ❌ {table_name}: ошибка - {e}")
    
    # Шаг 3: Логирование завершения всего процесса
    end_time = datetime.now()
    log_operation(conn, 'ETL_PROCESS', 'FULL_LOAD', start_time, end_time, 0, 'SUCCESS')
    
    # Вывод итоговой статистики
    print("\n" + "=" * 60)
    print(f"✅ ETL-ПРОЦЕСС ЗАВЕРШЁН")
    print(f"   Время выполнения: {end_time - start_time}")
    print("=" * 60)
    
    conn.close()  # Закрываем соединение

# Точка входа в программу
if __name__ == "__main__":
    main()