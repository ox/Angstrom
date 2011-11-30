desc "Push actors to github, switch to master, merge actors, push master to github"
namespace :super do
  task :push do
    `go master`
    `git merge actors`
    `git push github`
    `go actors`
  end
end

desc "Build gem"
task :gb do
  `gem build angstrom.gemspec`
end

desc "Push gem"
task :gp do
  Rake::Task[:gb].invoke
  gem_file = `ls *.gem`.to_a.last.chomp
  puts "pushing #{gem_file}"
  puts `gem push #{gem_file}`
end
