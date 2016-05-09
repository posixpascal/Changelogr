#!/usr/bin/ruby

require 'ruby-progressbar'
require 'erb'
require_relative './repository.rb'

module Changelogr
	class Changelogr
		attr_accessor :config, :path

		def self.banner
puts "                                                 
 _____  _                         _                
|     || |_  ___  ___  ___  ___  | | ___  ___  ___ 
|   --||   || .'||   || . || -_| | || . || . ||  _|
|_____||_|_||__,||_|_||_  ||___| |_||___||_  ||_|  
twitter @pascalraszyk |___| Chaos reigns |___| V0.5
===================================================
"                      
		end

		def initialize options = {}
			defaults = {
				:name => "Changelogr",
				:logo => "",
				:output => "CHANGELOG.md",
				:header => "Automated generated changelog",
				:contributors => true,
				:overwrite => true,
				:repository => :auto,
				:commits => :all,
				:excludes => [],
				:sections => {
					:fix => {
						:title => "Fixes",
						:match => /fix(?:\((?<group>.+)\))?\: (?<message>.+)/
					},
					:feature => {
						:title => "Features",
						:match => /feature(?:\((?<group>.+)\))?\: (?<message>.+)/
					},
					:docs => {
						:title => "Documentation changes",
						:match => /docs(?:\((?<group>.+)\))?\: (?<message>.+)/
					},
					:style => {
						:title => "Code Style chanes",
						:match => /style(?:\((?<group>.+)\))?\: (?<message>.+)/
					},
					:test => {
						:title => "Test changes",
						:match => /test(?:\((?<group>.+)\))?\: (?<message>.+)/
					},

					:bump => { # this is for meta only.
						:ignore => true,
						:match => /bump(?:\((?<group>.+)\))?\: (?<message>.+)/
					},
					:release => { # this is for meta only.
						:ignore => true,
						:match => /release(?:\((?<group>.+)\))?\: (?<message>.+)/
					},

					:other => { # list every unmatched commit
						:title => "Other changes",
						:match => /(?<message>.+)/,
					},
				},
				:templates => {
					:header => "templates/header.md.erb",
					:footer => "templates/footer.md.erb",
					:section => "templates/section.md.erb",
					:sections => "templates/sections.md.erb",
					:commit => "templates/commit.md.erb",
					:commit_group => "templates/commit_group.md.erb",
					:contributor => "templates/contributor.md.erb"
				},
				:groups => true,
				:start_from => [:commit, :first],
				:link_commit_hash => true,
			}
			@config = defaults.merge(options)
			@path = File.dirname(__FILE__)
			Changelogr.banner()
		end


		def generate!
			@git = Repository.new(@config[:repository])
			output = @config[:output]
			start_from = get_starting_sha()
			puts "All commits until: #{start_from}"
			commits = []
			@git.commits.each { |commit|
				break if commit.sha == start_from
				commits << commit
				
			}
			puts "Building changelog fom: #{commits.size} commits"
			#progressbar = ProgressBar.create :title => "Building", :total => (@config[:sections].size * commits.size)
			sections = []
			@config[:sections].each { |section, data|
				section = data
				unless section[:ignore]	
					regex = section[:match]
					section = {
						:keyname => section,
						:title => section[:title],
						:commits => [],
						:regex => regex
					}
					
					section[:commits] = commits.select do |commit|
						res = commit.message =~ regex
						if res 
							commits = commits.select {|c|
								commit.sha != c.sha
							}
						end
						res
					end
					if not section[:commits]
						section[:commits] = []
					end
					sections << section
				end
			}

			app_name = @config[:name]
			release_name = @config[:release_name] ||= app_name

			version = @config[:version]
			if not version # get version from last tag (and bump it)
				if @git.tags.last.nil?
						version = false
				else
					version = @git.tags.last.name
					if version.start_with? "v"
						version.sub!("v", "")
						version = version.split(".")
						version.map!(&:to_i)
						while	version.size < 3
							version << 0
						end
						version[2] = version[2] +  1
						version = version.join(".")
					end # no tag, lets ignore version
				end
			end
			
			puts "Preparing templates..."

			# preparing templates
			header = ERB.new File.read(File.join(@path, @config[:templates][:header]))
			contributor = ERB.new File.read(File.join(@path, @config[:templates][:contributor]))
			footer = ERB.new File.read(File.join(@path, @config[:templates][:footer]))
			sections_tpl = ERB.new File.read(File.join(@path, @config[:templates][:sections]))
			commit_tpl = ERB.new File.read(File.join(@path, @config[:templates][:commit]))
			commit_group_tpl = ERB.new File.read(File.join(@path, @config[:templates][:commit_group]))
			section_tpl = ERB.new File.read(File.join(@path, @config[:templates][:section]))

			puts "Building..."
			out = ""
			out += header.result(binding)

			sections.each do |section|
				group = false
				out += section_tpl.result(binding)
				commits_grouped = {:__DEFAULT_GROUP__ => []}
				old = ""
			
				section[:commits].each do |commit|
					begin
						group = commit.message.match(section[:regex])[:group]
					rescue
						group = :__DEFAULT_GROUP__
					end
					if group.nil?
						group = :__DEFAULT_GROUP__
					end
					message = commit.message.match(section[:regex])[:message]
					if commits_grouped[group].nil?
						 commits_grouped[group] = [] 
					end
					commits_grouped[group] << commit
				end
				commits_grouped.each do |group, commits| 
					if group == :__DEFAULT_GROUP__
						group = false # just print commits
					end
					if commits.size > 1 && group
						out += commit_group_tpl.result(binding)
						group = false
					end
					commits.each do |commit|
						message = commit.message.match(section[:regex])[:message]
						out += commit_tpl.result(binding)
					end
				end
			end

			out += footer.result(binding)
			#if File.exists? output 
				open(output, "w").write(out)
			#end
			puts "Done."

			
		end

		def repository= (val)
			@config[:repository] = val
		end

		def repository
			@config[:repository]
		end

		def start_from=(val)
			@config[:start_from] = val
		end

		def start_from
			@config[:start_from]
		end

		private
		def get_starting_sha()
			commits = @git.commits
			# lets look for special @bump or @release commits
			bump_or_releases = commits.select { |commit|
				commit.with_config @config
				commit.matches? :bump or commit.matches? :release
			}

			if bump_or_releases.any?
				return bump_or_releases.first.sha # return last release or bump commit
			end

			if @config[:start_from][0] == :tag 
				tagname = @config[:start_from][1].to_s
				
			

				tags = @git.tags.select {|commit|
					commit.name == tagname
				}
				if tags.any?
					return tags.first.sha
				end
			end


			if @config[:start_from][0] == :commit and @config[:start_from][1] == :first
				return commits.last.sha
			end

			return commits.last.sha

		end
	end
	module Commit
		attr_accessor :config
		def matches? section
			regex = @config[:sections][section][section]
			self.message =~ regex
		end

		def with_config config
			@config = config
		end
	end
	
end



