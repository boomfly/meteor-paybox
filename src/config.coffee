import {PACKAGE_NAME} from './constants'

isTest = process.env.PAYBOX_IS_TEST or true

Meteor.settings.public[PACKAGE_NAME] = {
  isTest
}

Meteor.settings.private = {} unless Meteor.settings.private
Meteor.settings.private[PACKAGE_NAME] = {
  siteUrl: process.env.PAYBOX_SITE_URL or Meteor.absoluteUrl()
  secretKey: process.env.PAYBOX_SECRET_KEY
  callbackScriptName: 'paybox'
  callbackMethod: process.env.PAYBOX_CALLBACK_METHOD or 'post'
  currency: 'USD'
  language: 'RU'
  isTest
}

export getConfig = -> Meteor.settings.private[PACKAGE_NAME]

export setConfig = (cfg) -> Object.assign(Meteor.settings.private[PACKAGE_NAME], cfg)