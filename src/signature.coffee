import { URL } from 'url'
import path from 'path'
import crypto from 'crypto'
import {sprintf} from 'sprintf-js'

export default class Signature
  @getScriptNameFromUrl: (url) ->
    try
      urlObj = new URL(url)
    catch
      return path.basename url
    pathname = urlObj.pathname
    len = pathname.length
    if len is 0 or '/' is pathname[-1]
      return ''

    path.basename pathname

  @make: (scriptName, params, secretKey) ->
    flatParams = @makeFlatParamsArray(params)
    # console.log '@make', flatParams
    crypto.createHash('md5').update(@makeSigStr(scriptName, flatParams, secretKey)).digest('hex')

  @check: (signature, scriptName, params, secretKey) ->
    signature is @make(scriptName, params, secretKey)

  @makeSigStr: (scriptName, params, secretKey) ->
    params = _.omit params, 'pg_sig'
    flatParams = [scriptName]
    keys = _.sortBy _.keys(params), (key) -> key
    _.map(keys, (key) -> flatParams.push params[key])
    flatParams.push secretKey
    flatParams.join ';'

  @makeFlatParamsArray: (params, parentName) ->
    parentName = '' unless parentName
    flatParams = {}
    i = 0
    for key, val of params
      i++
      if key in ['pg_sig', 'action']
        continue

      # /**
      #  * Имя делаем вида tag001subtag001
      #  * Чтобы можно было потом нормально отсортировать и вложенные узлы не запутались при сортировке
      #  */
      name = parentName + key + sprintf('%03d', i)
      if _.isObject(val)
        _.extend flatParams, @makeFlatParamsArray(val, name)
        continue
      flatParams[name] = val
    flatParams
