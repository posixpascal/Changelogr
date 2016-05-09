#!/usr/bin/ruby

require_relative '../lib/changelogr.rb'

changelogr = Changelogr::Changelogr.new()
changelogr.repository = "."
changelogr.start_from = [:commit, :first]
changelogr.generate!