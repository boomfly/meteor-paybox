import signature from '/imports/api/paybox/signature.coffee'
import Paybox from '/imports/api/paybox/paybox.coffee'
import {sprintf} from 'sprintf-js'
import { HTTP } from 'meteor/http'
import { Random } from 'meteor/random'

orderId = Random.id()
amount = 50
siteUrl = 'https://dalacoin.com'
checkUrl = 'https://dalacoin.com/api/paybox?action=check'
resultUrl = 'https://dalacoin.com/api/paybox?action=result'

params =
  pg_order_id: orderId
  pg_amount: sprintf("%01.2f", amount)
  pg_description: "Оплата заказа "
  pg_user_ip: '192.168.1.103'
  pg_site_url: siteUrl
  pg_lifetime: 60 * 60
  pg_user_phone: '77072457590'
  pg_language: 'RU'
  pg_result_url: resultUrl
  # pg_currency = 'KZT'
  # pg_check_url = checkUrl

# Paybox.initPayment params, (error, result) ->
#   console.log error, result
