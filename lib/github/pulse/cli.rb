# frozen_string_literal: true

require "thor"
require "json"

module Github
  module Pulse
    class CLI < Thor
      desc "analyze [REPO_PATH]", "Analyze GitHub repository activity"
      option :repo, type: :string, desc: "GitHub repository (owner/repo format)"
      option :token, type: :string, desc: "GitHub token (or set GITHUB_TOKEN env, or use gh CLI)"
      option :output, type: :string, default: "github-pulse-report.json", desc: "Output file path"
      option :format, type: :string, default: "json", enum: ["json", "pretty", "html"], desc: "Output format"
      option :since, type: :string, desc: "Analyze activity since this date (YYYY-MM-DD)"
      option :until, type: :string, desc: "Analyze activity until this date (YYYY-MM-DD)"
      option :small_threshold, type: :numeric, default: 50, desc: "PR size threshold for 'small' (additions+deletions)"
      option :medium_threshold, type: :numeric, default: 250, desc: "PR size threshold for 'medium' (additions+deletions)"
      
      def analyze(repo_path = ".")
        token = options[:token] || ENV["GITHUB_TOKEN"]
        
        analyzer = Analyzer.new(
          repo_path: repo_path,
          github_repo: options[:repo],
          token: token,
          since: options[:since],
          until: options[:until],
          small_threshold: options[:small_threshold],
          medium_threshold: options[:medium_threshold]
        )
        
        puts "Analyzing repository activity..."
        report = analyzer.analyze
        
        output_file = options[:output]
        
        if options[:format] == "html"
          require_relative "html_reporter"
          reporter = HtmlReporter.new(report)
          output = reporter.generate
          output_file = output_file.sub(/\.json$/, '.html') unless output_file.end_with?('.html')
        else
          reporter = Reporter.new(report)
          output = reporter.generate(format: options[:format].to_sym)
        end
        
        File.write(output_file, output)
        puts "Report saved to #{output_file}"
        
        if options[:format] == "pretty"
          puts "\n" + output
        elsif options[:format] == "html"
          puts "Open #{output_file} in your browser to view the interactive report"
          
          # Try to open in browser automatically
          case RUBY_PLATFORM
          when /darwin/
            system("open", output_file)
          when /linux/
            system("xdg-open", output_file)
          when /win32|mingw/
            system("start", output_file)
          end
        end
      rescue StandardError => e
        say "Error: #{e.message}", :red
        exit 1
      end
      
      desc "version", "Display version"
      def version
        puts "github-pulse #{Github::Pulse::VERSION}"
      end
      
      default_task :analyze
    end
  end
end
