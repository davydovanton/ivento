
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "ivento/version"

Gem::Specification.new do |spec|
  spec.name          = "ivento"
  spec.version       = Ivento::VERSION
  spec.authors       = ["Anton Davydov"]
  spec.email         = ["antondavydov.o@gmail.com"]

  spec.summary       = %q{Simple event sourcing framework in functional style}
  spec.description   = %q{Simple event sourcing framework in functional style}
  spec.homepage      = "https://github.com/davydovanton/ivento"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'concurrent-ruby'
  spec.add_dependency 'concurrent-ruby-edge'

  spec.add_dependency 'dry-struct'

  # pg adapter
  spec.add_development_dependency "sequel"
  spec.add_development_dependency "pg"

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
