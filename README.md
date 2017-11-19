# Meteor Paybox.money integration

Прием платежей через платежный шлюз Paybox.money для Meteor.js.

## Установка

```shell
meteor add boomfly:meteor-paybox
```

## Пример использования

```coffeescript
import React from 'react'
import ReactDOM from 'react-dom'
import Paybox from 'meteor/boomfly:meteor-paybox'

Paybox.config
  secretKey: ''                   # Секретный ключ из настроек магазина
  merchantId: ''                  # Идентификатор продавца
  siteUrl: 'https://example.com'
  currency: 'KZT'
  testingMode: true               # Тестовый режим для отладки подключения
  debug: true


if Meteor.isServer
  Meteor.methods
    placeOrder: (amount) ->
      params =
        pg_amount: amount
      try
        response = Paybox.initPaymentSync params
      catch error
        response = error
      response

if Meteor.isClient
  class PaymentButton extends React.Component
    placeOrder: ->
      Meteor.call 'placeOrder', 100, (error, result) ->
        window.location.href = result.pg_redirect_url._text # Переправляем пользователя на страницу оплаты

    render: ->
      <button className='btn btn-success' onClick={@placeOrder}>Оплатить 100 KZT</button>

  ReactDOM.render <PaymentButton />, document.getElementById('app')
```

## API

### Paybox.initPayment(params, callback)

Инициализация платежа

**params** - Объект, полный список допустимых параметров можно посмотреть на [странице](https://paybox.money/kz_ru/dev/payment-init)

**callback** - Функция обработчик разультата, принимает 2 параметра (error, result)

Доступна синхронная версия функции `Paybox.initPaymentSync` через [Meteor.wrapAsync](https://docs.meteor.com/api/core.html#Meteor-wrapAsync)

## Events

### Paybox.onResult(callback)

Обработка результата платежа

**callback** - Функция обработки результата платежа, принимает 1 параметр (params). Полный список параметров на [странице](https://paybox.money/kz_ru/dev/payment-result)

### Paybox.onCheck(callback)

Проверка возможности совершения платежа

**callback** - Функция проверки возможности совершения платежа, принимает 1 параметр (params). Полный список параметров на [странице](https://paybox.money/kz_ru/dev/payment-check)

**return** - Функция должна вернуть объект с результатом проверки. Результат функции будет конвертирован в `xml` и отправлен ответом на запрос Paybox.

**пример**:

```coffeescript
Paybox.onCheck (params) ->
  order = Order.findOne params.pg_order_id
  if not order
    pg_status: 'rejected'
    pg_description: "Order with _id: '#{params.pg_order_id}' not found"
  else
    if order.status is OrderStatus.PENDING_PAYMENT
      pg_status: 'ok'
    else if order.status is OrderStatus.CANCELLED
      pg_status: 'rejected'
      pg_description: 'Order cancelled'
    else if order.status is OrderStatus.PROCESSED
      pg_status: 'rejected'
      pg_description: 'Order already processed'
```
