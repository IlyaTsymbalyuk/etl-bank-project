# ETL Банковские данные

## Описание
ETL-процесс загрузки банковских данных из CSV-файлов в PostgreSQL.

## Технологии
- Python 3.13
- PostgreSQL 17
- psycopg2, pandas

## Структура
- `etl_full.py` - основной ETL-скрипт
- `sql/create_tables.sql` - создание схем и таблиц
- `data/` - исходные CSV-файлы

## Запуск
1. Создать БД и выполнить `sql/create_tables.sql`
2. Настроить подключение в `config.py`
3. Запустить `python etl_full.py`

## Результат
- Загружено 6 таблиц
- Логирование в `LOGS.ETL_LOG`