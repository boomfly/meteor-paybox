import { WebApp } from 'meteor/webapp'
import { Meteor } from 'meteor/meteor'
import { Random } from 'meteor/random'
import { check, Match } from 'meteor/check'
import {fetch} from 'meteor/fetch'
import {URL, URLSearchParams} from 'url'

# import convert from 'xml-js'
# import { Js2Xml } from 'js2xml'
import {XMLBuilder, XMLParser} from 'fast-xml-parser'

import PGSignature from './signature'
import {getConfig, setConfig} from './config'

BASE_URL = 'https://api.freedompay.money'
BASE_URL_V1 = 'https://api.freedompay.money/v1'

class Paybox
  constructor: ->
    config = getConfig()
    # Маршруты для обработки REST запросов от Cloudpayments Callback
    pathname = "/api/#{config.callbackScriptName}"
    @_registerHandler pathname

  config: (cfg) -> if cfg then setConfig(cfg) else getConfig()
  onResult: (cb) -> @_onResult = cb
  onCheck: (cb) -> @_onCheck = cb
  onFailure: (cb) -> @_onFailure = cb

  initPayment: (params, cb) ->
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

    @_request({script: 'init_payment.php', params})

  ###
  Синхронная версия метода initPayment
  ###
  @initPaymentSync: Meteor.wrapAsync @initPayment, @

  paymentSystemList: (params, cb) ->
    @call 'ps_list.php', params, cb

  getCards: (params) ->

  addCard: (params) ->
    config = getConfig()
    params.pg_post_link = "/api/#{config.callbackScriptName}?add_card"
    await @_request({
      script: 'add2',
      pathname: "v1/merchant/#{config.merchantId}/cardstorage/add2",
      params,
    })

  _request: (args) ->
    {script, pathname, params} = args
    pathname = script unless pathname

    config = getConfig()
    
    if config.isTest
      params.pg_testing_mode = 1
    params.pg_merchant_id = config.merchantId
    params.pg_salt = Random.id()
    params.pg_sig = @_sign(script, params)

    apiUrl = BASE_URL

    try
      apiUrl = new URL(pathname, apiUrl)
      response = await fetch(apiUrl.toString(), {
        method: 'POST',
        body: new URLSearchParams(params),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        }
      })
      console.log 'Paybox.call', response

      text = await response.text()

      xmlParser = new XMLParser()
      result = xmlParser.parse(text)

      if response.status isnt 200
        console.log 'Paybox._request', result
        throw new Meteor.Error(result.response?.error_code, result.response?.error_description)

      console.log('paybox.call', result)
      return result.response
    catch e
      console.log 'Paybox._request', e
      throw e

  _sign: (script, params) ->
    config = getConfig()
    PGSignature.make(script, params, config.secretKey);

  _registerHandler: (pathname, shouldUpdateWebhook = true) ->
    config = @config()
    handlerIndex = WebApp.handlers.router.stack.findIndex (i) => i.handler is @_handler
    if handlerIndex > 0
      WebApp.handlers.router.stack.splice handlerIndex, 1
    WebApp.handlers.use pathname, @_handler

  # Webhooks handler
  _handler: (req, res, next) =>
    config = @config()
    method = req.method
    url = new URL(Meteor.absoluteUrl(req.url))
    query = Object.fromEntries(url.searchParams)

    response = (code, params) =>
      if params
        params.pg_sig = @_sign("#{config.callbackScriptName}?action=#{params.action}", params)
        xmlBuilder = new XMLBuilder()
        response = xmlBuilder.build({response: params})

      res.writeHead code
      if params
        res.setHeader 'Content-Type', 'application/xml'
        res.end response

    console.log 'Paybox.handler method', method, req.headers, req.url

    if method is 'POST'
      chunksLength = 0
      chunks = []

      body = await new Promise (resolve, reject) ->
        req.on 'data', (chunk) ->
          # console.log 'Paybox.handler POST data chunk', chunk
          chunks.push(chunk)
          chunksLength += chunk.length
        req.on 'end', -> resolve Buffer.concat(chunks, chunksLength).toString('utf-8')
        req.on 'error', reject

      unless body
        console.warn 'Paybox.handler: Empty POST body'
        return response 400

      console.log 'Paybox.handler method', body

      payload = body
      if req.headers['content-type']?.indexOf('json') isnt -1
        params = JSON.parse(body)
      else
        params = Object.fromEntries(new URLSearchParams(body))
    else
      url = new URL(Meteor.absoluteUrl(req.url))
      payload = url.searchParams.toString()
      params = query
      unless payload
        console.warn 'Paybox.handler: Empty GET query'
        return response 400

    console.log 'Paybox.handler', payload, params

    signatureHeader = req.headers[SIGNATURE_HEADER_NAME]

    unless signatureHeader
      console.warn 'Paybox.handler: Request without signature', {[SIGNATURE_HEADER_NAME]: signatureHeader}
      return response 401

    # signature = @_sign payload, @_signatureSecret
    signature = @_sign payload, config.secretKey

    # TODO: signature generation algo
    # pg_sig = PGSignature.make("#{config.callbackScriptName}?action=#{params.action}", params, config.secretKey);

    if signature isnt signatureHeader
      console.warn 'Paybox.handler: Wrong request signature. Hack possible', {
        signature
        [SIGNATURE_HEADER_NAME]: signatureHeader
      }
      return response 401

    switch query.action
      when 'check'
        result = @_onCheck?(params)
      when 'result'
        result = @_onResult?(params)
      when 'failure'
        result = @_onFailure?(params)
      else
        result = {
          pg_status: 'error'
          pg_description: "Unknown action"
        }

    unless result
      result = {
        pg_status: 'error'
        pg_description: 'Unknown error'
      }
    result.pg_salt = params.pg_salt

    if config.debug
      console.log 'Paybox.restRoute.response', params.action, result

    return response 200, JSON.stringify(result)

export default Paybox = new Paybox

# Маршруты для обработки REST запросов от Paybox

# Rest = new Restivus
#   useDefaultAuth: true
#   prettyJson: true

# responseXml = (params, context) ->
#   params.pg_sig = PGSignature.make(config.callbackScriptName, params, config.secretKey)

#   xmlBuilder = new XMLBuilder()
#   response = xmlBuilder.build({response: params})

#   if context
#     context.writeHead 200,
#       'Content-Type': 'application/xml'
#     context.write(response)
#     context.done()
#     return undefined
#   else
#     headers:
#       'Content-Type': 'application/xml'
#     body: response

# # http://localhost:3200/api/paybox?action=result&amount=50&order_id=vYyioup4zJG9Tk5vd
# Meteor.startup ->
#   Rest.addRoute config.callbackScriptName, {authRequired: false},
#     "#{config.callbackMethod}": ->
#       if config.debug
#         console.log 'Paybox.restRoute', @queryParams, @bodyParams

#       if @queryParams?.pg_payment_id?
#         params = _.omit @queryParams, ['__proto__']
#       else if @bodyParams?.pg_payment_id?
#         params = _.omit @bodyParams, ['__proto__']
#       else
#         params = {}

#       pg_sig = PGSignature.make("#{config.callbackScriptName}?action=#{params.action}", params, config.secretKey);

#       # if pg_sig isnt params.pg_sig
#       #   console.log 'Paybox.restRoute invalid signature', pg_sig
#       #   return
#       #     statusCode: 403
#       #     body: 'Access restricted 403'

#       switch params.action
#         when 'check'
#           response = Paybox._onCheck?(params)
#         when 'result'
#           response = Paybox._onResult?(params)
#         when 'failure'
#           response = Paybox._onFailure?(params)
#         else
#           response =
#             pg_status: 'error'
#             pg_description: "Unknown action"

#       unless response
#         response =
#           pg_status: 'error'
#           pg_description: 'Unknown error'
#       response.pg_salt = params.pg_salt

#       if config.debug
#         console.log 'Paybox.restRoute.response', params.action, response

#       responseXml response
