# frozen_string_literal: true

require "rugged"
require "time"

module Github
  module Pulse
    class GitAnalyzer
      attr_reader :repository, :repo_path

      def initialize(repo_path)
        @repo_path = repo_path
        @repository = Rugged::Repository.new(repo_path)
      rescue Rugged::RepositoryError => e
        raise Error, "Not a valid git repository: #{repo_path}"
      end

      def analyze_commits(since: nil, until_date: nil)
        walker = Rugged::Walker.new(repository)
        walker.push(repository.head.target_id)
        
        commits_by_author = Hash.new { |h, k| h[k] = [] }
        
        walker.each do |commit|
          commit_time = Time.at(commit.time)
          
          if since && commit_time < Time.parse(since)
            break
          end
          
          if until_date && commit_time > Time.parse(until_date)
            next
          end
          
          author = commit.author[:email]
          commits_by_author[author] << {
            sha: commit.oid,
            message: commit.message.lines.first&.strip,
            time: commit_time,
            additions: 0,
            deletions: 0
          }
        end
        
        commits_by_author.each do |author, commits|
          commits.each do |commit_data|
            stats = calculate_commit_stats(commit_data[:sha])
            commit_data[:additions] = stats[:additions]
            commit_data[:deletions] = stats[:deletions]
          end
        end
        
        commits_by_author
      end

      def lines_of_code_by_author
        blame_data = Hash.new(0)
        
        repository.head.target.tree.walk(:preorder) do |root, entry|
          next unless entry[:type] == :blob
          
          file_path = root.empty? ? entry[:name] : "#{root}/#{entry[:name]}"
          
          next if binary_file?(file_path)
          
          begin
            blame = Rugged::Blame.new(repository, file_path)
            blame.each do |hunk|
              author = hunk[:final_signature][:email]
              lines = hunk[:lines_in_hunk]
              blame_data[author] += lines
            end
          rescue StandardError
            next
          end
        end
        
        blame_data
      end

      def commit_activity_by_day
        walker = Rugged::Walker.new(repository)
        walker.push(repository.head.target_id)
        
        activity = Hash.new(0)
        
        walker.each do |commit|
          date = Time.at(commit.time).to_date
          activity[date] += 1
        end
        
        activity.sort.to_h
      end

      def remote_url
        remotes = repository.remotes
        return nil if remotes.count == 0
        
        origin = remotes["origin"]
        return nil unless origin
        
        url = origin.url
        extract_github_repo(url)
      end

      private

      def calculate_commit_stats(sha)
        commit = repository.lookup(sha)
        
        if commit.parents.empty?
          tree = commit.tree
          stats = { additions: 0, deletions: 0 }
          
          tree.walk(:preorder) do |root, entry|
            next unless entry[:type] == :blob
            blob = repository.lookup(entry[:oid])
            stats[:additions] += blob.content.lines.count
          end
          
          stats
        else
          parent = commit.parents.first
          diff = parent.diff(commit)
          
          stats = { additions: 0, deletions: 0 }
          diff.each_patch do |patch|
            patch.hunks.each do |hunk|
              hunk.lines.each do |line|
                case line.line_origin
                when :addition
                  stats[:additions] += 1
                when :deletion
                  stats[:deletions] += 1
                end
              end
            end
          end
          
          stats
        end
      rescue StandardError
        { additions: 0, deletions: 0 }
      end

      def binary_file?(path)
        extensions = %w[.jpg .jpeg .png .gif .pdf .zip .tar .gz .exe .dll .so .dylib .o .a]
        extensions.any? { |ext| path.downcase.end_with?(ext) }
      end

      def extract_github_repo(url)
        patterns = [
          %r{github\.com[:/]([^/]+/[^/]+?)(?:\.git)?$},
          %r{git@github\.com:([^/]+/[^/]+?)(?:\.git)?$}
        ]
        
        patterns.each do |pattern|
          if match = url.match(pattern)
            return match[1]
          end
        end
        
        nil
      end
    end
  end
end