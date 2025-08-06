# frozen_string_literal: true

require_relative "lib/github/pulse/version"

Gem::Specification.new do |spec|
  spec.name = "github-pulse"
  spec.version = Github::Pulse::VERSION
  spec.authors = ["Jonathan Siegel"]
  spec.email = ["<248302+usiegj00@users.noreply.github.com>"]

  spec.summary = "Analyze GitHub repository activity and contributions"
  spec.description = "A Ruby gem to analyze GitHub repository activity, including pull requests, lines of code, and commit activity by contributor. Generates visualization-ready JSON output."
  spec.homepage = "https://github.com/usiegj00/github-pulse"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/usiegj00/github-pulse"
  spec.metadata["changelog_uri"] = "https://github.com/usiegj00/github-pulse/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "octokit", "~> 9.0"
  spec.add_dependency "rugged", "~> 1.7"
  spec.add_dependency "thor", "~> 1.3"
  spec.add_dependency "json", "~> 2.7"
  spec.add_dependency "time", "~> 0.3"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
