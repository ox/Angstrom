desc "Push actors to github, switch to master, merge actors, push master to github"
namespace :super do
  task :push do
    `git push github`
    `go master`
    `git merge actors`
    `git push github`
    `go actors`
  end
end

namespace :g do
  desc "Build gem"
  task :b do
    `gem build armstrong.gemspec`
  end

  desc "Push gem"
  task :p do
    Rake::Task["g:b"].invoke
    gem_file = `ls *.gem`.to_a.last.chomp
    puts "pushing #{gem_file}"
    puts `gem push #{gem_file}`
  end
end