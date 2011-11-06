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

#### ZMQ and other gems ####
	gem install zmq
	gem install lazy

it should also install `ffi` and `ffi-rzmq` which are to dynamically load libs and call functions from them. Interesting stuff, but out of the scope of this measly README.

#### Mongrel2 ####
Finally, go grab a copy of mongrel2 (1.7.5 tested) from the [Mongrel2](http://mongrel2.org) website.

There's a sample `mongrel2.conf` and `config.sqlite` in the `demo` folder, feel free to use those. Otherwise, load the `mongrel2.conf` into `m2sh` and then start the server.

	m2sh load -config mongrel2.conf -db config.sqlite
	m2sh start -host localhost

## minimal example ##

	require './lib/armstrong'
	
	get "/" do
		output_string "hello world"
	end

Just like in Sinatra, we state the verb we want to use, the path, and give it a block with the relevant code to execute. So far only 'GET' requests are supported but more will come out in later builds. 

You can also call the `get_message` method which returns the request from the browser, and then reply to the request with `reply(request, message)`. `reply_string(message)` is a helper function that grabs the message and instantly replies to it with `message`.

Now you should run `ruby armstrong_test.rb` and then visit [localhost:6767](http://localhost:6767/) and relish in the 'Hello World'.

## benchmarking ##

	$ time curl localhost:6767/
	Hello World
	real	0m0.014s
	user	0m0.007s
	sys		0m0.004s

## License ##
GPLv3