# Mercuryo Ruby Challenge

## Описание задания

Необходимо реализовать сервис аккаунтинга, который ведет учет балансов и транзакций.

К каждому магазину будет привязан счет.
Он будет пополняться виртуальной суммой менеджером.
При прохождении успешного платежа, его сумма должна списываться со счета.
Если денег на счету недостаточно - платеж должен отклоняться.

### Требования к производительности

Сервис должен быть рассчитан на высокую нагрузку:
- Количество аккаунтов: тысячи
- Объем транзакций: десятки миллионов записей

## Текущая архитектура сервисов

```mermaid
flowchart LR
    A["api-gateway"] --> B["core"]
    B --> C["provider-gateway"]
    B --> D["antifraud"]
    C --> B
    D --> B
```

## Текущая схема статусов

```mermaid
stateDiagram-v2
    [*] --> created

    created --> antifraud_check_success
    created --> antifraud_check_failed
    antifraud_check_failed --> [*]

    antifraud_check_success --> provider_payout_processing

    provider_payout_processing --> provider_payout_processing
    provider_payout_processing --> provider_payout_failed
    provider_payout_processing --> provider_payout_success

    provider_payout_failed --> [*]
    provider_payout_success --> [*]
```

## Миграции (Sequel)

Запуск миграций:

```bash
cd app
bundle exec ruby db/migrate.rb
```
