# frozen_string_literal: true

module Github
  module Pulse
    class HtmlReporter
      attr_reader :report

      def initialize(report)
        @report = report
      end

      def generate
        <<~HTML
          <!DOCTYPE html>
          <html lang="en">
          <head>
              <meta charset="UTF-8">
              <meta name="viewport" content="width=device-width, initial-scale=1.0">
              <title>GitHub Pulse Report - #{report.dig(:metadata, :repository, :full_name) || 'Repository'}</title>
              <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
              <script src="https://cdn.jsdelivr.net/npm/date-fns@2.29.3/index.min.js"></script>
              <style>
                  * {
                      margin: 0;
                      padding: 0;
                      box-sizing: border-box;
                  }
                  body {
                      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
                      line-height: 1.6;
                      color: #333;
                      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                      min-height: 100vh;
                      padding: 20px;
                  }
                  .container {
                      max-width: 1400px;
                      margin: 0 auto;
                      background: rgba(255, 255, 255, 0.95);
                      border-radius: 20px;
                      padding: 30px;
                      box-shadow: 0 20px 60px rgba(0,0,0,0.3);
                  }
                  h1 {
                      color: #2d3748;
                      margin-bottom: 10px;
                      font-size: 2.5em;
                      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                      -webkit-background-clip: text;
                      -webkit-text-fill-color: transparent;
                  }
                  .subtitle {
                      color: #718096;
                      margin-bottom: 30px;
                      font-size: 1.1em;
                  }
                  .stats-grid {
                      display: grid;
                      grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
                      gap: 20px;
                      margin-bottom: 40px;
                  }
                  .stat-card {
                      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                      color: white;
                      padding: 20px;
                      border-radius: 15px;
                      box-shadow: 0 4px 6px rgba(0,0,0,0.1);
                  }
                  .stat-value {
                      font-size: 2em;
                      font-weight: bold;
                      margin-bottom: 5px;
                  }
                  .stat-label {
                      opacity: 0.9;
                      font-size: 0.9em;
                      text-transform: uppercase;
                      letter-spacing: 1px;
                  }
                  .charts-grid {
                      display: grid;
                      grid-template-columns: repeat(auto-fit, minmax(500px, 1fr));
                      gap: 30px;
                      margin-bottom: 30px;
                  }
                  .chart-container {
                      background: white;
                      padding: 25px;
                      border-radius: 15px;
                      box-shadow: 0 4px 6px rgba(0,0,0,0.1);
                  }
                  .chart-title {
                      font-size: 1.3em;
                      color: #2d3748;
                      margin-bottom: 20px;
                      font-weight: 600;
                  }
                  canvas {
                      max-height: 400px;
                  }
                  .contributors-table {
                      background: white;
                      border-radius: 15px;
                      padding: 25px;
                      box-shadow: 0 4px 6px rgba(0,0,0,0.1);
                      margin-top: 30px;
                  }
                  table {
                      width: 100%;
                      border-collapse: collapse;
                  }
                  th {
                      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                      color: white;
                      padding: 12px;
                      text-align: left;
                      font-weight: 600;
                  }
                  td {
                      padding: 12px;
                      border-bottom: 1px solid #e2e8f0;
                  }
                  tr:hover {
                      background-color: #f7fafc;
                  }
                  .progress-bar {
                      width: 100%;
                      height: 20px;
                      background: #e2e8f0;
                      border-radius: 10px;
                      overflow: hidden;
                  }
                  .progress-fill {
                      height: 100%;
                      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                      border-radius: 10px;
                      transition: width 0.3s ease;
                  }
                  .metadata {
                      background: #f7fafc;
                      padding: 15px;
                      border-radius: 10px;
                      margin-bottom: 30px;
                      display: flex;
                      justify-content: space-between;
                      flex-wrap: wrap;
                      gap: 20px;
                  }
                  .metadata-item {
                      display: flex;
                      align-items: center;
                      gap: 10px;
                  }
                  .metadata-label {
                      font-weight: 600;
                      color: #4a5568;
                  }
                  .no-data {
                      text-align: center;
                      padding: 40px;
                      color: #718096;
                      font-style: italic;
                  }
              </style>
          </head>
          <body>
              <div class="container">
                  <h1>GitHub Pulse Report</h1>
                  <div class="subtitle">Repository Activity Analysis</div>
                  
                  #{generate_metadata_section}
                  #{generate_stats_cards}
                  
                  <div class="charts-grid">
                      #{generate_commit_activity_chart}
                      #{generate_lines_of_code_chart}
                      #{generate_commits_timeline_chart}
                      #{generate_pull_requests_chart}
                      #{generate_prs_timeline_chart}
                      #{generate_pr_status_chart}
                      #{generate_pr_cycle_time_chart}
                      #{generate_pr_size_mix_chart}
                      #{generate_open_prs_aging_chart}
                  </div>
                  #{generate_commit_heatmap}
                  
                  #{generate_contributors_table}
              </div>
              
              <script>
                  #{generate_chart_scripts}
              </script>
          </body>
          </html>
        HTML
      end

      private

      def generate_metadata_section
        metadata = report[:metadata]
        repo = metadata[:repository]
        period = metadata[:period]
        
        items = []
        items << %(<div class="metadata-item"><span class="metadata-label">Repository:</span> #{repo[:full_name]}</div>) if repo
        items << %(<div class="metadata-item"><span class="metadata-label">Analyzed:</span> #{format_time(metadata[:analyzed_at])}</div>)
        items << %(<div class="metadata-item"><span class="metadata-label">Period:</span> #{period[:since] || 'All time'} to #{period[:until] || 'Present'}</div>) if period[:since] || period[:until]
        
        %(<div class="metadata">#{items.join}</div>)
      end

      def generate_stats_cards
        stats = calculate_stats
        
        <<~HTML
          <div class="stats-grid">
              <div class="stat-card">
                  <div class="stat-value">#{stats[:total_contributors]}</div>
                  <div class="stat-label">Contributors</div>
              </div>
              <div class="stat-card">
                  <div class="stat-value">#{stats[:total_commits]}</div>
                  <div class="stat-label">Total Commits</div>
              </div>
              <div class="stat-card">
                  <div class="stat-value">#{stats[:total_prs]}</div>
                  <div class="stat-label">Pull Requests</div>
              </div>
              <div class="stat-card">
                  <div class="stat-value">#{format_number(stats[:total_lines])}</div>
                  <div class="stat-label">Lines of Code</div>
              </div>
              <div class="stat-card">
                  <div class="stat-value">+#{format_number(stats[:total_additions])}</div>
                  <div class="stat-label">Additions</div>
              </div>
              <div class="stat-card">
                  <div class="stat-value">-#{format_number(stats[:total_deletions])}</div>
                  <div class="stat-label">Deletions</div>
              </div>
          </div>
        HTML
      end

      def generate_commit_activity_chart
        return %(<div class="chart-container"><div class="no-data">No commit activity data available</div></div>) if report[:visualization_data].nil? || report[:visualization_data][:commit_activity_chart].nil?
        
        <<~HTML
          <div class="chart-container">
              <h3 class="chart-title">Daily Commit Activity</h3>
              <canvas id="commitActivityChart"></canvas>
          </div>
        HTML
      end

      def generate_lines_of_code_chart
        return %(<div class="chart-container"><div class="no-data">No lines of code data available</div></div>) if report[:visualization_data].nil? || report[:visualization_data][:lines_of_code_chart].nil?
        
        <<~HTML
          <div class="chart-container">
              <h3 class="chart-title">Lines of Code by Contributor</h3>
              <canvas id="linesOfCodeChart"></canvas>
          </div>
        HTML
      end

      def generate_commits_timeline_chart
        return %(<div class="chart-container"><div class="no-data">No commits timeline data available</div></div>) if report[:visualization_data].nil? || report[:visualization_data][:commits_timeline].nil?
        
        <<~HTML
          <div class="chart-container">
              <h3 class="chart-title">Commits Over Time</h3>
              <canvas id="commitsTimelineChart"></canvas>
          </div>
        HTML
      end

      def generate_pull_requests_chart
        return "" if report[:pull_requests].empty?
        ""  # We'll use separate charts for PRs
      end
      
      def generate_prs_timeline_chart
        return %(<div class="chart-container"><div class="no-data">No pull requests data available</div></div>) if report[:visualization_data].nil? || report[:visualization_data][:pull_requests_timeline].nil?
        
        <<~HTML
          <div class="chart-container">
              <h3 class="chart-title">Pull Requests Over Time</h3>
              <canvas id="prsTimelineChart"></canvas>
          </div>
        HTML
      end
      
      def generate_pr_status_chart
        return %(<div class="chart-container"><div class="no-data">No pull requests data available</div></div>) if report[:pull_requests].empty?
        
        <<~HTML
          <div class="chart-container">
              <h3 class="chart-title">Pull Requests by Status</h3>
              <canvas id="prStatusChart"></canvas>
          </div>
        HTML
      end

      def generate_pr_cycle_time_chart
        return %(<div class="chart-container"><div class="no-data">No PR cycle time data available</div></div>) if report[:visualization_data].nil? || report[:visualization_data][:pr_cycle_time_timeline].nil?
        <<~HTML
          <div class="chart-container">
              <h3 class="chart-title">PR Cycle Time (days)</h3>
              <canvas id="prCycleTimeChart"></canvas>
          </div>
        HTML
      end

      def generate_pr_size_mix_chart
        return %(<div class="chart-container"><div class="no-data">No PR size data available</div></div>) if report[:visualization_data].nil? || report[:visualization_data][:pr_size_mix_timeline].nil?
        <<~HTML
          <div class="chart-container">
              <h3 class="chart-title">PR Size Mix Over Time</h3>
              <canvas id="prSizeMixChart"></canvas>
          </div>
        HTML
      end

      def generate_open_prs_aging_chart
        return %(<div class="chart-container"><div class="no-data">No open PRs</div></div>) if report[:visualization_data].nil? || report[:visualization_data][:open_prs_aging].nil?
        <<~HTML
          <div class="chart-container">
              <h3 class="chart-title">Open PRs Aging</h3>
              <canvas id="openPrsAgingChart"></canvas>
          </div>
        HTML
      end

      def generate_commit_heatmap
        return %(<div class="chart-container"><div class="no-data">No commit heatmap data available</div></div>) if report[:visualization_data].nil? || report[:visualization_data][:commit_activity_heatmap].nil?
        heatmap = report[:visualization_data][:commit_activity_heatmap]
        days = %w[Sun Mon Tue Wed Thu Fri Sat]
        # Build a simple grid table with intensity via inline background
        rows = heatmap.each_with_index.map do |hours, wday|
          cells = hours.each_with_index.map do |count, hour|
            intensity = [count, 10].min # cap for color scale
            color = "rgba(102,126,234,#{0.1 + intensity * 0.09})"
            %(<td title="#{days[wday]} #{hour}:00 — #{count}" style="background: #{color}; text-align:center; font-size: 12px;">#{count}</td>)
          end.join
          %(<tr><th style="position:sticky;left:0;background:#fff;">#{days[wday]}</th>#{cells}</tr>)
        end.join
        hours_header = (0..23).map { |h| %(<th>#{h}</th>) }.join
        <<~HTML
          <div class="chart-container">
              <h3 class="chart-title">Commit Activity Heatmap</h3>
              <div style="overflow:auto">
              <table>
                  <thead>
                      <tr><th></th>#{hours_header}</tr>
                  </thead>
                  <tbody>
                      #{rows}
                  </tbody>
              </table>
              </div>
          </div>
        HTML
      end

      def generate_contributors_table
        contributors = gather_contributor_stats
        return "" if contributors.empty?
        
        max_commits = contributors.map { |c| c[:commits] }.max.to_f
        
        rows = contributors.map do |contributor|
          <<~ROW
            <tr>
                <td>#{contributor[:name]}</td>
                <td>#{contributor[:commits]}</td>
                <td>
                    <div class="progress-bar">
                        <div class="progress-fill" style="width: #{(contributor[:commits] / max_commits * 100).round}%"></div>
                    </div>
                </td>
                <td>+#{format_number(contributor[:additions])}</td>
                <td>-#{format_number(contributor[:deletions])}</td>
                <td>#{format_number(contributor[:lines])} lines</td>
                <td>#{contributor[:prs]} PRs</td>
            </tr>
          ROW
        end.join
        
        <<~HTML
          <div class="contributors-table">
              <h3 class="chart-title">Contributor Statistics</h3>
              <table>
                  <thead>
                      <tr>
                          <th>Contributor</th>
                          <th>Commits</th>
                          <th>Activity</th>
                          <th>Additions</th>
                          <th>Deletions</th>
                          <th>Current Lines</th>
                          <th>Pull Requests</th>
                      </tr>
                  </thead>
                  <tbody>
                      #{rows}
                  </tbody>
              </table>
          </div>
        HTML
      end

      def generate_chart_scripts
        viz_data = report[:visualization_data] || {}
        
        scripts = []
        
        # Commit Activity Chart
        if viz_data[:commit_activity_chart]
          data = viz_data[:commit_activity_chart]
          labels = data.map { |d| "'#{d[:date]}'" }.join(', ')
          values = data.map { |d| d[:commits] }.join(', ')
          
          scripts << <<~JS
            new Chart(document.getElementById('commitActivityChart'), {
                type: 'line',
                data: {
                    labels: [#{labels}],
                    datasets: [{
                        label: 'Commits',
                        data: [#{values}],
                        borderColor: '#667eea',
                        backgroundColor: 'rgba(102, 126, 234, 0.1)',
                        tension: 0.4,
                        fill: true
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: { display: false }
                    },
                    scales: {
                        y: { beginAtZero: true }
                    }
                }
            });
          JS
        end
        
        # Lines of Code Chart
        if viz_data[:lines_of_code_chart]
          data = viz_data[:lines_of_code_chart]
          labels = data.map { |d| "'#{d[:author]}'" }.join(', ')
          values = data.map { |d| d[:lines] }.join(', ')
          
          scripts << <<~JS
            new Chart(document.getElementById('linesOfCodeChart'), {
                type: 'bar',
                data: {
                    labels: [#{labels}],
                    datasets: [{
                        label: 'Lines of Code',
                        data: [#{values}],
                        backgroundColor: [
                            '#667eea', '#764ba2', '#f093fb', '#f5576c',
                            '#4facfe', '#00f2fe', '#43e97b', '#fa709a'
                        ]
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: { display: false }
                    },
                    scales: {
                        y: { beginAtZero: true }
                    }
                }
            });
          JS
        end
        
        # Commits Timeline Chart
        if viz_data[:commits_timeline]
          data = viz_data[:commits_timeline]
          labels = data.map { |d| "'#{d[:date]}'" }
          authors = data.flat_map { |d| d[:authors].keys }.uniq
          
          datasets = authors.map.with_index do |author, i|
            values = data.map { |d| d[:authors][author] || 0 }
            colors = ['#667eea', '#764ba2', '#f093fb', '#f5576c', '#4facfe', '#00f2fe']
            {
              label: author,
              data: values,
              backgroundColor: colors[i % colors.length],
              borderColor: colors[i % colors.length]
            }
          end
          
          scripts << <<~JS
            new Chart(document.getElementById('commitsTimelineChart'), {
                type: 'bar',
                data: {
                    labels: [#{labels.join(', ')}],
                    datasets: #{datasets.to_json}
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    scales: {
                        x: { stacked: true },
                        y: { stacked: true, beginAtZero: true }
                    }
                }
            });
          JS
        end
        
        # Pull Requests Timeline Chart
        if viz_data[:pull_requests_timeline]
          data = viz_data[:pull_requests_timeline]
          labels = data.map { |d| "'#{d[:date]}'" }
          authors = data.flat_map { |d| d[:authors].keys }.uniq
          
          datasets = authors.map.with_index do |author, i|
            values = data.map { |d| d[:authors][author] || 0 }
            colors = ['#667eea', '#764ba2', '#f093fb', '#f5576c', '#4facfe', '#00f2fe']
            {
              label: author,
              data: values,
              backgroundColor: colors[i % colors.length],
              borderColor: colors[i % colors.length]
            }
          end
          
          scripts << <<~JS
            new Chart(document.getElementById('prsTimelineChart'), {
                type: 'line',
                data: {
                    labels: [#{labels.join(', ')}],
                    datasets: #{datasets.to_json}
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    scales: {
                        y: { 
                            beginAtZero: true,
                            ticks: {
                                stepSize: 1
                            }
                        }
                    },
                    plugins: {
                        tooltip: {
                            mode: 'index',
                            intersect: false
                        }
                    }
                }
            });
          JS
        end
        
        # Pull Requests Status Chart
        unless report[:pull_requests].empty?
          pr_stats = { merged: 0, open: 0, closed: 0 }
          report[:pull_requests].each do |_, data|
            pr_stats[:merged] += data[:merged]
            pr_stats[:open] += data[:open]
            pr_stats[:closed] += data[:closed]
          end
          
          scripts << <<~JS
            new Chart(document.getElementById('prStatusChart'), {
                type: 'doughnut',
                data: {
                    labels: ['Merged', 'Open', 'Closed'],
                    datasets: [{
                        data: [#{pr_stats[:merged]}, #{pr_stats[:open]}, #{pr_stats[:closed]}],
                        backgroundColor: ['#48bb78', '#4299e1', '#f56565']
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false
                }
            });
          JS
        end

        # PR Cycle Time Chart
        if viz_data[:pr_cycle_time_timeline]
          data = viz_data[:pr_cycle_time_timeline]
          labels = data.map { |d| "'#{d[:week]}'" }.join(', ')
          p50 = data.map { |d| d[:p50] }.join(', ')
          p90 = data.map { |d| d[:p90] }.join(', ')
          maxv = data.map { |d| d[:max] }.join(', ')
          scripts << <<~JS
            new Chart(document.getElementById('prCycleTimeChart'), {
              type: 'line',
              data: {
                labels: [#{labels}],
                datasets: [
                  { label: 'p50', data: [#{p50}], borderColor: '#48bb78', fill: false },
                  { label: 'p90', data: [#{p90}], borderColor: '#ed8936', fill: false },
                  { label: 'max', data: [#{maxv}], borderColor: '#f56565', fill: false }
                ]
              },
              options: { responsive: true, maintainAspectRatio: false }
            });
          JS
        end

        # PR Size Mix Chart
        if viz_data[:pr_size_mix_timeline]
          data = viz_data[:pr_size_mix_timeline]
          labels = data.map { |d| "'#{d[:week]}'" }.join(', ')
          small = data.map { |d| d[:small] }.join(', ')
          medium = data.map { |d| d[:medium] }.join(', ')
          large = data.map { |d| d[:large] }.join(', ')
          scripts << <<~JS
            new Chart(document.getElementById('prSizeMixChart'), {
              type: 'bar',
              data: {
                labels: [#{labels}],
                datasets: [
                  { label: 'Small', data: [#{small}], backgroundColor: '#63b3ed' },
                  { label: 'Medium', data: [#{medium}], backgroundColor: '#667eea' },
                  { label: 'Large', data: [#{large}], backgroundColor: '#764ba2' }
                ]
              },
              options: { responsive: true, maintainAspectRatio: false, scales: { x: { stacked: true }, y: { stacked: true, beginAtZero: true } } }
            });
          JS
        end

        # Open PRs Aging Chart
        if viz_data[:open_prs_aging]
          labels = viz_data[:open_prs_aging].keys.map { |k| "'#{k}'" }.join(', ')
          values = viz_data[:open_prs_aging].values.join(', ')
          scripts << <<~JS
            new Chart(document.getElementById('openPrsAgingChart'), {
              type: 'doughnut',
              data: {
                labels: [#{labels}],
                datasets: [{ data: [#{values}], backgroundColor: ['#68d391', '#63b3ed', '#ed8936', '#f56565'] }]
              },
              options: { responsive: true, maintainAspectRatio: false }
            });
          JS
        end

        scripts.join("\n")
      end

      def calculate_stats
        stats = {
          total_contributors: 0,
          total_commits: 0,
          total_prs: 0,
          total_lines: 0,
          total_additions: 0,
          total_deletions: 0
        }
        
        # Count contributors
        contributors = Set.new
        contributors.merge(report[:commits].keys) if report[:commits]
        contributors.merge(report[:pull_requests].keys) if report[:pull_requests]
        stats[:total_contributors] = contributors.size
        
        # Count commits and changes
        if report[:commits]
          report[:commits].each do |_, data|
            stats[:total_commits] += data[:total_commits]
            stats[:total_additions] += data[:total_additions]
            stats[:total_deletions] += data[:total_deletions]
          end
        end
        
        # Count PRs
        if report[:pull_requests]
          report[:pull_requests].each do |_, data|
            stats[:total_prs] += data[:total_prs]
          end
        end
        
        # Count lines
        if report[:lines_of_code]
          stats[:total_lines] = report[:lines_of_code].values.sum
        end
        
        stats
      end

      def gather_contributor_stats
        contributors = {}
        
        # Gather commit stats
        if report[:commits]
          report[:commits].each do |author, data|
            contributors[author] ||= { name: author, commits: 0, additions: 0, deletions: 0, lines: 0, prs: 0 }
            contributors[author][:commits] = data[:total_commits]
            contributors[author][:additions] = data[:total_additions]
            contributors[author][:deletions] = data[:total_deletions]
          end
        end
        
        # Add lines of code
        if report[:lines_of_code]
          report[:lines_of_code].each do |author, lines|
            contributors[author] ||= { name: author, commits: 0, additions: 0, deletions: 0, lines: 0, prs: 0 }
            contributors[author][:lines] = lines
          end
        end
        
        # Add PR stats
        if report[:pull_requests]
          report[:pull_requests].each do |author, data|
            contributors[author] ||= { name: author, commits: 0, additions: 0, deletions: 0, lines: 0, prs: 0 }
            contributors[author][:prs] = data[:total_prs]
          end
        end
        
        contributors.values.sort_by { |c| -c[:commits] }
      end

      def format_time(time_str)
        return "N/A" unless time_str
        Time.parse(time_str).strftime("%B %d, %Y at %I:%M %p")
      rescue
        time_str
      end

      def format_number(num)
        return "0" unless num
        num.to_s.reverse.scan(/\d{1,3}/).join(',').reverse
      end
    end
  end
end
