import { Meteor } from 'meteor/meteor'
import { Random } from 'meteor/random'
import { check, Match } from 'meteor/check'
import { HTTP } from 'meteor/http'

# import convert from 'xml-js'
# import { Js2Xml } from 'js2xml'
import {XMLBuilder, XMLParser} from 'fast-xml-parser'

import PGSignature from './signature'
import config from './config'

export default class Paybox
  @config: (cfg) -> if cfg then _.extend(config, cfg) else _.extend({}, config)
  @onResult: (cb) -> @_onResult = cb
  @onCheck: (cb) -> @_onCheck = cb
  @onFailure: (cb) -> @_onFailure = cb

  @call: (script, params, cb) ->
    if config.testingMode
      params.pg_testing_mode = 1
    params.pg_merchant_id = config.merchantId
    params.pg_salt = Random.id()
    params.pg_sig = PGSignature.make(script, params, config.secretKey);
    try
      result = HTTP.post "https://api.paybox.money/#{script}", {params}
      # console.log 'Paybox.call', result
      xmlParser = new XMLParser()
      # result = convert.xml2js result.content, compact: true
      result = xmlParser.parse(result.content)
      console.log('paybox.call', result)
      if cb then cb(null, result.response)
    catch e
      if cb then cb(e, null)

  @initPayment: (params, cb) ->
    _.extend params,
      pg_site_url: config.siteUrl
      pg_language: config.language
      pg_currency: config.currency

    if @_onResult
      params.pg_result_url = "#{config.siteUrl}/api/#{config.callbackScriptName}?action=result"

    if @_onCheck
      params.pg_check_url = "#{config.siteUrl}/api/#{config.callbackScriptName}?action=check"

    if @_onFailure
      params.pg_failure_url = "#{config.siteUrl}/api/#{config.callbackScriptName}?action=failure"

    if config.successUrl
      params.pg_success_url = config.successUrl

    @call 'init_payment.php', params, cb

  ###
  Синхронная версия метода initPayment
  ###
  @initPaymentSync: Meteor.wrapAsync @initPayment, @

  @paymentSystemList: (params, cb) ->
    @call 'ps_list.php', params, cb

# Маршруты для обработки REST запросов от Paybox

Rest = new Restivus
  useDefaultAuth: true
  prettyJson: true

responseXml = (params, context) ->
  params.pg_sig = PGSignature.make(config.callbackScriptName, params, config.secretKey)

  xmlBuilder = new XMLBuilder()
  response = xmlBuilder.build({response: params})

  if context
    context.writeHead 200,
      'Content-Type': 'application/xml'
    context.write(response)
    context.done()
    return undefined
  else
    headers:
      'Content-Type': 'application/xml'
    body: response

# http://localhost:3200/api/paybox?action=result&amount=50&order_id=vYyioup4zJG9Tk5vd
Meteor.startup ->
  Rest.addRoute config.callbackScriptName, {authRequired: false},
    "#{config.callbackMethod}": ->
      if config.debug
        console.log 'Paybox.restRoute', @queryParams, @bodyParams

      if @queryParams?.pg_payment_id?
        params = _.omit @queryParams, ['__proto__']
      else if @bodyParams?.pg_payment_id?
        params = _.omit @bodyParams, ['__proto__']
      else
        params = {}

      pg_sig = PGSignature.make("#{config.callbackScriptName}?action=#{params.action}", params, config.secretKey);

      # if pg_sig isnt params.pg_sig
      #   console.log 'Paybox.restRoute invalid signature', pg_sig
      #   return
      #     statusCode: 403
      #     body: 'Access restricted 403'

      switch params.action
        when 'check'
          response = Paybox._onCheck?(params)
        when 'result'
          response = Paybox._onResult?(params)
        when 'failure'
          response = Paybox._onFailure?(params)
        else
          response =
            pg_status: 'error'
            pg_description: "Unknown action"

      unless response
        response =
          pg_status: 'error'
          pg_description: 'Unknown error'
      response.pg_salt = params.pg_salt

      if config.debug
        console.log 'Paybox.restRoute.response', params.action, response

      responseXml response
