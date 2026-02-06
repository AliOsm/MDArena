source "https://rubygems.org"

gem "rails", "~> 8.1.2"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"

# Authentication
gem "devise"

# Inertia.js + Vite
gem "inertia_rails"
gem "vite_rails"

# Git operations
gem "rugged"

# Background jobs
gem "good_job"

# PDF generation
gem "grover"

# Markdown rendering
gem "commonmarker"

# Caching & real-time
gem "solid_cache"
gem "solid_cable"

# Collaborative editing
gem "y-rb"

# JSON APIs
gem "jbuilder"

# Windows timezone data
gem "tzinfo-data", platforms: %i[windows jruby]

# Boot performance
gem "bootsnap", require: false

# Deployment
gem "kamal", require: false
gem "thruster", require: false

# Active Storage image processing
gem "image_processing", "~> 1.2"

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "bundler-audit", require: false
  gem "brakeman", require: false

  # Linting
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-minitest", require: false
  gem "rubocop-performance", require: false
end

group :development do
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end
