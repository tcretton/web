const redis = require('redis')
const { client } = require('nightwatch-api')
const fs = require('fs-extra')
const { promisify } = require('util')

const { join } = require('./path')
const userSettings = require('./userSettings')

exports.clearVersion = async function (user) {
  const redisClient = redis.createClient()
  const getAsync = promisify(redisClient.get).bind(redisClient)
  const keysAsync = promisify(redisClient.keys).bind(redisClient)
  const delAsync = promisify(redisClient.del).bind(redisClient)
  const endAsync = promisify(redisClient.end).bind(redisClient)

  const keys = await keysAsync('*')

  for (const elem of keys) {
    const val = await getAsync(elem)
    console.log(elem)
    console.log(val)
    if (!val || val.startsWith(join(client.globals.ocis_data_dir, 'data', user))) {
      // console.log('Deleting: ' + val)
      await delAsync(elem)
    }
  }
  console.log('Deleting versions for user ' + user)
  console.log('Deleting directory ' + join(client.globals.ocis_data_dir, 'data', user, 'files_versions'))
  fs.removeSync(join(client.globals.ocis_data_dir, 'data', user, 'files_versions'))
  return endAsync()
}

exports.clearAllVersion = async function () {
  const redisClient = redis.createClient()

  const getAsync = promisify(redisClient.get).bind(redisClient)
  const keysAsync = promisify(redisClient.keys).bind(redisClient)
  const delAsync = promisify(redisClient.del).bind(redisClient)
  const endAsync = promisify(redisClient.end).bind(redisClient)

  // const flushAsync = promisify(redisClient.flushdb).bind(redisClient)
  //
  // return flushAsync()
  const keys = await keysAsync('*')

  for (const elem of keys) {
    const val = await getAsync(elem)
    // console.log('Deleting: ' + val)
    await delAsync(elem)
  }

  for (const user of userSettings.createdUsers) {
    console.log('Deleting directory ' + join(client.globals.ocis_data_dir, 'data', user, 'files_versions'))
    console.log('Deleting versions for user ' + user)
    fs.removeSync(join(client.globals.ocis_data_dir, 'data', user, 'files_versions'))
  }
  return endAsync()
}
