#!/usr/bin/ruby

require 'git'

module Changelogr
	class Repository
		attr_accessor :git
		def initialize repository = :auto
			if repository == :auto
				repository = "."
			end

			@git = Git.open(repository)
			Git::Object::Commit.include Commit
		end

		def commits
			@git.log(nil).since(0)
		end

		# delegate
		def method_missing sym, *args, &block
			@git.send sym, *args, &block
		end
	end

end