# Скрипт для загрузки CSV-файлов в слой RD (сырые данные)
# Используется тот же подход, что и в Задании 1.1
# Загружаются три файла: сделки, кредитные каникулы, справочник продуктов

import psycopg2  # для подключения к PostgreSQL
import pandas as pd  # для чтения CSV файлов
from datetime import datetime  # для временных меток в логах
from config import DB_CONFIG  # настройки подключения из config.py

# Пути к файлам (можно изменить под свою структуру папок)
DEAL_INFO_PATH = "data/deal_info.csv"           # данные о сделках
LOAN_HOLIDAY_PATH = "data/loan_holiday.csv"     # данные о кредитных каникулах
PRODUCT_INFO_PATH = "data/product_info.csv"     # справочник продуктов
LOG_PATH = "load_to_rd_log.txt"                 # файл для записи логов

def log_message(message):
    """Записывает сообщение в лог-файл и выводит на экран"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(LOG_PATH, "a", encoding="utf-8") as f:
        f.write(f"{timestamp} - {message}\n")
    print(f"{timestamp} - {message}")

def load_deal_info(conn):
    """Загружает данные о сделках из CSV в таблицу rd.deal_info"""
    log_message("Начало загрузки rd.deal_info")
    
    # Читаем CSV файл (разделитель - запятая)
    df = pd.read_csv(DEAL_INFO_PATH, sep=',')
    log_message(f"Прочитано строк из CSV: {len(df)}")
    
    # Преобразуем текстовые даты в формат DATE
    date_columns = ['deal_start_date', 'effective_from_date', 'effective_to_date']
    for col in date_columns:
        if col in df.columns:
            df[col] = pd.to_datetime(df[col]).dt.date
    
    # Заменяем пустые значения (NaN) на None (в PostgreSQL это будет NULL)
    df = df.where(pd.notnull(df), None)
    
    cur = conn.cursor()
    
    # Очищаем таблицу перед загрузкой (полная перезагрузка)
    # Это гарантирует, что старые данные не смешаются с новыми
    cur.execute("TRUNCATE TABLE rd.deal_info")
    log_message("Таблица rd.deal_info очищена")
    
    # Вставляем данные построчно
    inserted_count = 0
    for _, row in df.iterrows():
        cur.execute("""
            INSERT INTO rd.deal_info (
                deal_rk, deal_num, deal_name, deal_sum, client_rk, account_rk,
                agreement_rk, deal_start_date, department_rk, product_rk,
                deal_type_cd, effective_from_date, effective_to_date
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, (
            row['deal_rk'], row['deal_num'], row['deal_name'], row['deal_sum'],
            row['client_rk'], row['account_rk'], row['agreement_rk'],
            row['deal_start_date'], row['department_rk'], row['product_rk'],
            row['deal_type_cd'], row['effective_from_date'], row['effective_to_date']
        ))
        inserted_count += 1
    
    conn.commit()  # фиксируем изменения в базе данных
    cur.close()
    log_message(f"Загружено записей в rd.deal_info: {inserted_count}")

def load_loan_holiday(conn):
    """Загружает данные о кредитных каникулах из CSV в таблицу rd.loan_holiday"""
    log_message("Начало загрузки rd.loan_holiday")
    
    # Читаем CSV файл
    df = pd.read_csv(LOAN_HOLIDAY_PATH, sep=',')
    log_message(f"Прочитано строк из CSV: {len(df)}")
    
    # Преобразуем даты
    date_columns = [
        'loan_holiday_start_date', 'loan_holiday_finish_date',
        'loan_holiday_fact_finish_date', 'loan_holiday_last_possible_date',
        'effective_from_date', 'effective_to_date'
    ]
    for col in date_columns:
        if col in df.columns:
            df[col] = pd.to_datetime(df[col]).dt.date
    
    # Заменяем пустые значения на NULL
    df = df.where(pd.notnull(df), None)
    
    cur = conn.cursor()
    
    # Очищаем таблицу
    cur.execute("TRUNCATE TABLE rd.loan_holiday")
    log_message("Таблица rd.loan_holiday очищена")
    
    # Вставляем данные
    inserted_count = 0
    for _, row in df.iterrows():
        cur.execute("""
            INSERT INTO rd.loan_holiday (
                deal_rk, loan_holiday_type_cd, loan_holiday_start_date,
                loan_holiday_finish_date, loan_holiday_fact_finish_date,
                loan_holiday_finish_flg, loan_holiday_last_possible_date,
                effective_from_date, effective_to_date
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, (
            row['deal_rk'], row['loan_holiday_type_cd'], row['loan_holiday_start_date'],
            row['loan_holiday_finish_date'], row['loan_holiday_fact_finish_date'],
            row['loan_holiday_finish_flg'], row['loan_holiday_last_possible_date'],
            row['effective_from_date'], row['effective_to_date']
        ))
        inserted_count += 1
    
    conn.commit()
    cur.close()
    log_message(f"Загружено записей в rd.loan_holiday: {inserted_count}")

def load_product_info(conn):
    """Загружает справочник продуктов из CSV в таблицу rd.product"""
    log_message("Начало загрузки rd.product")
    
    # Читаем CSV файл
    df = pd.read_csv(PRODUCT_INFO_PATH, sep=',')
    log_message(f"Прочитано строк из CSV: {len(df)}")
    
    # Преобразуем даты
    df['effective_from_date'] = pd.to_datetime(df['effective_from_date']).dt.date
    df['effective_to_date'] = pd.to_datetime(df['effective_to_date']).dt.date
    
    # Заменяем пустые значения на NULL
    df = df.where(pd.notnull(df), None)
    
    cur = conn.cursor()
    
    # Очищаем таблицу
    cur.execute("TRUNCATE TABLE rd.product")
    log_message("Таблица rd.product очищена")
    
    # Вставляем данные
    inserted_count = 0
    for _, row in df.iterrows():
        cur.execute("""
            INSERT INTO rd.product (
                product_rk, product_name, effective_from_date, effective_to_date
            ) VALUES (%s, %s, %s, %s)
        """, (row['product_rk'], row['product_name'], row['effective_from_date'], row['effective_to_date']))
        inserted_count += 1
    
    conn.commit()
    cur.close()
    log_message(f"Загружено записей в rd.product: {inserted_count}")

def load_all():
    """Основная функция: загружает все три таблицы"""
    log_message("=" * 50)
    log_message("НАЧАЛО ЗАГРУЗКИ ДАННЫХ В СЛОЙ RD")
    log_message("=" * 50)
    
    # Подключаемся к базе данных
    conn_string = f"host={DB_CONFIG['host']} port={DB_CONFIG['port']} dbname={DB_CONFIG['database']} user={DB_CONFIG['user']} password={DB_CONFIG['password']}"
    conn = psycopg2.connect(conn_string)
    log_message("Подключение к базе данных установлено")
    
    # Загружаем каждую таблицу
    load_deal_info(conn)      # загрузка сделок
    load_loan_holiday(conn)   # загрузка кредитных каникул
    load_product_info(conn)   # загрузка справочника продуктов
    
    # Закрываем соединение
    conn.close()
    log_message("Соединение с базой данных закрыто")
    log_message("=" * 50)
    log_message("ЗАГРУЗКА ЗАВЕРШЕНА УСПЕШНО")
    log_message("=" * 50)

# Если скрипт запущен напрямую (а не импортирован), запускаем загрузку
if __name__ == "__main__":
    load_all()