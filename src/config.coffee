export default
  siteUrl: 'example.com'
  merchantId: '1234567890'
  secretKey: process.env.PAYBOX_SECRET_KEY
  callbackScriptName: 'paybox'
  callbackMethod: process.env.PAYBOX_CALLBACK_METHOD or 'post'
  currency: 'USD'
  language: 'RU'
  successUrl: null
