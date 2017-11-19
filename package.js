Package.describe({
  // Short two-sentence summary
  summary: 'Meteor Paybox.js integration',
  version: '0.1.0',
  name: 'boomfly:meteor-paybox',
  git: 'https://github.com/boomfly/meteor-paybox'
});


Package.onUse((api) => {
  api.versionsFrom('1.6');

  api.use('underscore', 'server');
  api.use('ecmascript', 'server');
  api.use('coffeescript@2.0.2_1', 'server');
  // api.imply('coffeescript', 'server');

  api.mainModule('src/paybox.coffee', 'server');
});
// This defines the tests for the package:
Package.onTest((api) => {
  // Sets up a dependency on this package.
  api.use('underscore', 'server');
  api.use('ecmascript', 'server');
  api.use('coffeescript@2.0.2_1', 'server');
  api.use('boomfly:meteor-paybox');
  // Specify the source code for the package tests.
  api.addFiles('test/test.coffee', 'server');
});
// This lets you use npm packages in your package:
Npm.depends({
  'sprintf-js': '1.1.1',
  'xml-js': '1.5.2'
});
