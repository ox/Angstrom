# Armstrong #
An evented, fiber-based server for Ruby. This project is heavily based on [Brubeck](http://brubeck.io). The goal was to make it really easy to make an evented server that acted quick and scaled infinitely. This is accomplished by using [Mongrel2](http://mongrel2.org), [ZeroMQ](http://zeromq.org) and [Rubinius](rubini.us). Rubinius has the actor gem included already so it makes it really convenient to just use rubinius. Also, the 2.0.0dev branch has super nice thread handling, allowing for true Ruby concurrency that MRI just can't offer with its GIL.

## Mongrel2 and ZeroMQ ##
Although it seems like a strange direction to start writing servers in, eventually most companies end up in the realm of evented servers. This is because it offers nearly infinite scalability for free.

This is possible because of Mongrel2 and ZeroMQ. Mongrel2 acts as your server and parses requests. It then sends out ZeroMQ messages to your handlers and proxies and then returns their responses. Because it uses ZeroMQ messages, Mongrel2 can send messages anywhere and to any language. Conversely, it sends messages in a round-robin style, so scalability is achieved by just starting up another instance of your server.

## setup ##
#### Rubinius ####

	rvm install rbx
	rvm use rbx

#### ZeroMQ ####
Go grab the zip from [zeromq/zeromq2-1](https://github.com/zeromq/zeromq2-1), unzip it, and in the directory run:
	
	./autogen.sh; ./configure; make; sudo make install

#### ZMQ gem ####
	gem install zmq

it should also install `ffi` and `ffi-rzmq` which are to dynamically load libs and call functions from them. Interesting stuff, but out of the scope of this measly README.

#### Mongrel2 ####
Finally, go grab a copy of mongrel2 (1.7.5 tested) from the [Mongrel2](http://mongrel2.org) website.

There's a sample `mongrel2.conf` and `config.sqlite` in the `demo` folder, feel free to use those. Otherwise, load the `mongrel2.conf` into `m2sh` and then start the server.

	m2sh load -config mongrel2.conf -db config.sqlite
	m2sh start -host localhost

## minimal example ##

	require './lib/armstrong'
	
	HelloProc = Proc.new do
	  output "Hello World"
	end

	app = Armstrong.new [[/\//, HelloProc]]
	app.run!

Here, we set up a handler, and a route to match to it. When we get any request, it is matched against all of our defined routes and sent to the handler defined by the first one. Since our proc just responds "Hello World" to everything, it just blocks until it gets data and then sends it off to replier to send it back to mongrel2. You must send back data, since it has the reply address and id's to respond to.

Now the fun part, when your mongrel2 server is up and running, run `ruby armstrong_test.rb` and then visit [localhost:6767](http://localhost:6767/) and relish in the 'Hello World'.

## benchmarking ##

	$ time curl localhost:6767/
	Hello World
	real	0m0.014s
	user	0m0.007s
	sys		0m0.004s

## License ##
GPLv3