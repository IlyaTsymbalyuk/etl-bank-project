# Скрипт для экспорта данных из таблицы в CSV файл

import psycopg2  # для подключения к PostgreSQL
import csv       # для записи в CSV файл
from datetime import datetime  # для временных меток в логах
from config import DB_CONFIG   # настройки подключения

# Имена файлов
CSV_PATH = "demo_f101_round_f_export.csv"  # сюда сохраняем CSV
LOG_PATH = "export_log.txt"                 # сюда пишем лог

def log_message(message):
    """Записывает сообщение в лог-файл и выводит на экран"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(LOG_PATH, "a", encoding="utf-8") as f:
        f.write(f"{timestamp} - {message}\n")
    print(f"{timestamp} - {message}")

def export_to_csv():
    log_message("Начало экспорта")
    
    # Подключаемся к базе данных
    conn_string = f"host={DB_CONFIG['host']} port={DB_CONFIG['port']} dbname={DB_CONFIG['database']} user={DB_CONFIG['user']} password={DB_CONFIG['password']}"
    conn = psycopg2.connect(conn_string)
    log_message("Подключено к БД")
    
    cur = conn.cursor()
    
    # Запрос на выборку всех данных из демо-таблицы
    query = """
        SELECT 
            from_date, to_date, chapter, ledger_account, characteristic,
            balance_in_rub, balance_in_val, balance_in_total,
            turn_deb_rub, turn_deb_val, turn_deb_total,
            turn_cre_rub, turn_cre_val, turn_cre_total,
            balance_out_rub, balance_out_val, balance_out_total
        FROM dm.demo_f101_round_f
        ORDER BY ledger_account
    """
    
    cur.execute(query)
    rows = cur.fetchall()  # получаем все строки
    
    # Получаем названия колонок
    col_names = [desc[0] for desc in cur.description]
    
    log_message(f"Получено записей: {len(rows)}")
    
    # Записываем данные в CSV файл
    # encoding='utf-8-sig' - для поддержки русских букв
    # delimiter=';' - разделитель точка с запятой
    with open(CSV_PATH, 'w', encoding='utf-8-sig', newline='') as f:
        writer = csv.writer(f, delimiter=';')
        writer.writerow(col_names)  # сначала пишем заголовки
        writer.writerows(rows)       # затем пишем все строки
    
    log_message(f"Данные сохранены в {CSV_PATH}")
    
    cur.close()
    conn.close()
    log_message("Экспорт завершен")

if __name__ == "__main__":
    export_to_csv()