export PACKAGE_NAME = if module.id.startsWith('/node_modules/meteor/') then module.id.split('/')[3] else null
