#!/usr/bin/ruby

require_relative '../lib/changelogr.rb'

changelogr = Changelogr::Changelogr.new()
changelogr.repository = "your repo/"
changelogr.start_from = [:tag, :"v1.0.1"]
changelogr.generate!