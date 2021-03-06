#!/usr/bin/ruby

require_relative '../lib/changelogr.rb'

changelogr = Changelogr::Changelogr.new()
changelogr.repository = "."
changelogr.start_from = [:commit, :first]
changelogr.name = "Changelogr"
changelogr.repo_url = "https://github.com/posixpascal/Changelogr"
changelogr.skip_release_check = true
changelogr.generate!