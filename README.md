# Mercuryo Ruby Challenge

## Описание задания

Необходимо реализовать сервис аккаунтинга, который ведет учет балансов и транзакций.

## Требования

Сервис должен поддерживать:

1. **Пополнение баланса** - одностадийная атомарная операция, которая сразу завершается и обновляет баланс аккаунта.

2. **Списание с баланса** - двухстадийная операция:
   - Первая стадия: резервирование средств (создание транзакции со статусом `pending`)
   - Вторая стадия: подтверждение или отмена списания (изменение статуса на `completed` или `cancelled`)

### Требования к производительности

Сервис должен быть рассчитан на высокую нагрузку:
- Количество аккаунтов: тысячи
- Объем транзакций: десятки миллионов записей

### Структура базы данных

#### Таблица `accounts`
- `id` (primary key)
- `balance` (decimal) - текущий баланс аккаунта, 2 десятичных знака
- `currency` (string) - валюта аккаунта
- `created_at` (timestamp)
- `updated_at` (timestamp)

#### Таблица `transactions`
- `id` (primary key)
- `account_id` (foreign key -> accounts.id)
- `currency` (string) - валюта транзакции
- `amount` (decimal) - сумма транзакции (может быть положительной для пополнения и отрицательной для списания)
- `status` (string) - статус транзакции:
  - `pending` - транзакция в процессе (для двухстадийного списания)
  - `completed` - транзакция завершена успешно
  - `cancelled` - транзакция отменена
- `uuid` (string, unique) - уникальный идентификатор транзакции
- `transaction_type` (string) - тип транзакции: `deposit` (пополнение) или `withdrawal` (списание)
- `created_at` (timestamp)
- `updated_at` (timestamp)

## Реализация

### Запуск

```bash
docker compose up --build
```

API доступно на `http://localhost:4321`.

### Миграции

```bash
docker compose run --rm api bundle exec ruby scripts/migrate.rb
```

### Тесты

```bash
docker compose run --rm api bundle exec ruby test/transactions_flow_test.rb
```

### API (REST)

Базовый префикс: `/api/v1`

1. Health:
   - `GET /api/v1/health`
2. Пополнение (одностадийно, `completed`):
   - `POST /api/v1/accounts/:account_id/deposits`
3. Резервирование списания (`pending`, уменьшает баланс сразу):
   - `POST /api/v1/accounts/:account_id/withdrawals`
4. Подтверждение списания:
   - `POST /api/v1/withdrawals/:uuid/confirm`
5. Отмена списания (возврат резерва в баланс):
   - `POST /api/v1/withdrawals/:uuid/cancel`

Пример тела запроса для `deposits`/`withdrawals`:

```json
{
  "uuid": "2ec29107-d0fb-4431-8162-4f0db8485cc5",
  "currency": "USD",
  "amount": "50.00"
}
```

### Бизнес-правила

- `pending`-списание резервирует средства: баланс уменьшается на этапе reserve.
- Идемпотентность по `uuid`:
  - одинаковый `uuid` + тот же payload -> возвращается существующая транзакция;
  - одинаковый `uuid` + другой payload -> `409 Conflict`.
- Валюта транзакции обязана совпадать с валютой аккаунта.
- Разрешенные переходы статусов списания:
  - `pending -> completed`
  - `pending -> cancelled`
- Любой другой переход -> `409 Conflict`.

### Производительность и консистентность

- Критичные операции выполняются в транзакциях БД.
- Используется блокировка строк (`FOR UPDATE`) для аккаунта/транзакции в операциях изменения состояния.
- Индексы:
  - уникальный `transactions.uuid`
  - `transactions(account_id, created_at)`
  - `transactions(status, created_at)`

### TODO

- Добавить аутентификацию/авторизацию для production-сценария.
