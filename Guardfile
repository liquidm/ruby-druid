# More info at https://github.com/guard/guard#readme
guard :bundler do
  watch('Gemfile')
end

guard :rspec, :cli => '--color --format nested' do
	watch(%r{^spec/.+_spec\.rb$})
	watch(%r{^(.+)\.rb$})  	{|m| "spec/#{m[1]}_spec.rb" }
  watch(%r{^lib/(.+)\.rb$})     { |m| "spec/lib/#{m[1]}_spec.rb" }
end