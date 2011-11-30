# Angstrom #
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
	
#### Angstrom as a gem ####

	gem install angstrom

#### ZMQ and other gems ####
	gem install ffi-rzmq
	gem install lazy

it should also install `ffi` and `ffi-rzmq` which are to dynamically load libs and call functions from them. Interesting stuff, but out of the scope of this measly README.

#### Mongrel2 ####
Finally, go grab a copy of mongrel2 (1.7.5 tested) from the [Mongrel2](http://mongrel2.org) website.

There's a sample `mongrel2.conf` and `config.sqlite` in the `demo` folder, feel free to use those. Otherwise, load the `mongrel2.conf` into `m2sh` and then start the server.

	m2sh load -config mongrel2.conf -db config.sqlite
	m2sh start -host localhost

## minimal example ##

	require 'angstrom'

	get "/" do
		"hello world"
	end

Just like in Sinatra, we state the verb we want to use, the path, and give it a block with the relevant code to execute. So far only 'GET' requests are supported but more will come out in later builds. 

Now you should run `ruby angstrom_test.rb` and then visit [localhost:6767](http://localhost:6767/) and relish in the 'Hello World'.

## more functionality ##

commit e86c74aed added functionality for parameters in your path. These are simply demonstrated in the `demo/angstrom_test.rb` file. For instance, you can extract the id of a certain part of your path like so:

	require 'angstrom'
	
	get "/:id" do |env|
		"id: #{env[:params]["id"]}"
	end
	
The params are always going to be stored in `env`, naturally.

You can also return other codes and custom headers by returning an array with the signature:
	[code, headers, response]

## benchmarking ##

#### Armstrong ####
	$ siege -d 1 -c 150 -t 10s localhost:6767/
	** SIEGE 2.70
	** Preparing 150 concurrent users for battle.
	The server is now under siege...
	Lifting the server siege...      done.
	Transactions:		        	5029 hits
	Availability:		      		100.00 %
	Elapsed time:		        	9.06 secs
	Data transferred:	        	0.05 MB
	Response time:		        	0.26 secs
	Transaction rate:	      		555.08 trans/sec
	Throughput:		        		0.01 MB/sec
	Concurrency:		      		146.56
	Successful transactions:        5029
	Failed transactions:	           0
	Longest transaction:	        0.67
	Shortest transaction:	        0.02
	
#### Sinatra ####

_These benchmarks were done using Rubinius as the Ruby interpreter. You will get much better results for sinatra with MRI 1.9.2 but the concurrency will still plateau at about 110. I could not start up more than 110 concurrent users without sinatra closing all connections and blowing up._

	$ siege -d1 -c 110 -t 10s localhost:4567/
	** SIEGE 2.70
	** Preparing 20 concurrent users for battle.
	The server is now under siege...
	Lifting the server siege...      done.
	Transactions:		        	1192 hits
	Availability:		       		97.23 %
	Elapsed time:		        	9.39 secs
	Data transferred:	        	0.01 MB
	Response time:		        	0.70 secs
	Transaction rate:	      		126.94 trans/sec
	Throughput:		        		0.00 MB/sec
	Concurrency:		       		88.98
	Successful transactions:        1192
	Failed transactions:	          34
	Longest transaction:	        1.39
	Shortest transaction:	        0.20

## License ##
GPLv3