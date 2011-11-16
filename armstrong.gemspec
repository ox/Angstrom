Gem::Specification.new 'armstrong', '0.2.6' do |s|
  s.description       = "Armstrong is an Mongrel2 fronted, actor-based web development framework similar in style to sinatra. With natively-threaded interpreters (Rubinius2), Armstrong provides true concurrency and high stability, by design."
  s.summary           = "Highly concurrent, sinatra-like framework"
  s.author            = "Artem Titoulenko"
  s.email             = "artem.titoulenko@gmail.com"
  s.homepage          = "https://www.github.com/artemtitoulenko/armstrong"
  s.files             = `git ls-files`.split("\n") - %w[.gitignore .travis.yml response_benchmark.rb demo/config.sqlite]
  s.executables       = %w[ armstrong ]

  s.add_dependency 'ffi',            '~> 1.0', '>= 1.0.10'
  s.add_dependency 'ffi-rzmq', '~> 0.9', '>= 0.9.0'
  s.add_dependency 'lazy', '>= 0.9.6'
end