const redis = require("redis")
const { promisify } = require("util");

const client = redis.createClient()

const elements = []
const getAsync = promisify(client.get).bind(client);
const keysAsync = promisify(client.keys).bind(client);

const get = async function() {
	const keys = await keysAsync("*")

	for (const elem of keys) {
		val = await getAsync(elem)
		elements.push(val)
	}
	console.log(elements.sort())
	client.end(false)
}

const clearAllVersion = async function () {
  const client = redis.createClient()

  const getAsync = promisify(client.get).bind(client)
  const keysAsync = promisify(client.keys).bind(client)
  const delAsync = promisify(client.del).bind(client)

  const keys = await keysAsync('*')

  for (const elem of keys) {
    const val = await getAsync(elem)
		console.log(val)
    await delAsync(elem)
  }
  client.end(false)
}

//get()
clearAllVersion()
