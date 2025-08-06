# frozen_string_literal: true

require "json"

module Github
  module Pulse
    class Reporter
      attr_reader :report

      def initialize(report)
        @report = report
      end

      def generate(format: :json)
        case format
        when :json
          JSON.generate(report)
        when :pretty
          JSON.pretty_generate(report)
        else
          raise ArgumentError, "Unknown format: #{format}"
        end
      end

      def summary
        lines = []
        lines << "GitHub Repository Activity Report"
        lines << "=" * 40
        
        if report[:metadata][:repository]
          repo = report[:metadata][:repository]
          lines << "Repository: #{repo[:full_name]}"
          lines << "Description: #{repo[:description]}" if repo[:description]
          lines << "Primary Language: #{repo[:language]}" if repo[:language]
          lines << "Stars: #{repo[:stars]} | Forks: #{repo[:forks]}"
          lines << ""
        end
        
        if report[:metadata][:period][:since] || report[:metadata][:period][:until]
          lines << "Analysis Period:"
          lines << "  From: #{report[:metadata][:period][:since] || 'Beginning'}"
          lines << "  To: #{report[:metadata][:period][:until] || 'Present'}"
          lines << ""
        end
        
        lines << "Analyzed at: #{report[:metadata][:analyzed_at]}"
        lines << ""
        
        # Commits summary
        if report[:commits].any?
          lines << "Commits by Author:"
          report[:commits].each do |author, data|
            lines << "  #{author}:"
            lines << "    Total Commits: #{data[:total_commits]}"
            lines << "    Additions: +#{data[:total_additions]}"
            lines << "    Deletions: -#{data[:total_deletions]}"
          end
          lines << ""
        end
        
        # Pull requests summary
        if report[:pull_requests].any?
          lines << "Pull Requests by Author:"
          report[:pull_requests].each do |author, data|
            lines << "  #{author}:"
            lines << "    Total PRs: #{data[:total_prs]}"
            lines << "    Merged: #{data[:merged]}"
            lines << "    Open: #{data[:open]}"
            lines << "    Closed: #{data[:closed]}"
            lines << "    Additions: +#{data[:total_additions]}"
            lines << "    Deletions: -#{data[:total_deletions]}"
          end
          lines << ""
        end
        
        # Lines of code
        if report[:lines_of_code].any?
          lines << "Current Lines of Code by Author:"
          sorted_loc = report[:lines_of_code].sort_by { |_, lines| -lines }
          total_lines = sorted_loc.sum { |_, lines| lines }
          
          sorted_loc.each do |author, line_count|
            percentage = (line_count.to_f / total_lines * 100).round(1)
            lines << "  #{author}: #{line_count} lines (#{percentage}%)"
          end
          lines << "  Total: #{total_lines} lines"
          lines << ""
        end
        
        # Commit activity summary
        if report[:commit_activity].any?
          total_commits = report[:commit_activity].values.sum
          lines << "Commit Activity:"
          lines << "  Total Commits: #{total_commits}"
          lines << "  Active Days: #{report[:commit_activity].size}"
          lines << "  Average Commits/Day: #{(total_commits.to_f / report[:commit_activity].size).round(1)}"
          lines << ""
        end
        
        lines.join("\n")
      end

      def to_csv
        require "csv"
        
        CSV.generate do |csv|
          # Add headers
          csv << ["Metric", "Author", "Value", "Details"]
          
          # Add commit data
          report[:commits].each do |author, data|
            csv << ["Commits", author, data[:total_commits], "Total commits"]
            csv << ["Additions", author, data[:total_additions], "Total lines added"]
            csv << ["Deletions", author, data[:total_deletions], "Total lines deleted"]
          end
          
          # Add PR data
          report[:pull_requests].each do |author, data|
            csv << ["Pull Requests", author, data[:total_prs], "Total PRs"]
            csv << ["PR Merged", author, data[:merged], "Merged PRs"]
            csv << ["PR Open", author, data[:open], "Open PRs"]
          end
          
          # Add lines of code data
          report[:lines_of_code].each do |author, lines|
            csv << ["Lines of Code", author, lines, "Current lines in codebase"]
          end
        end
      end
    end
  end
end