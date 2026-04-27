# Contributing to nahook-ruby

Thanks for considering a contribution! A few important things to know first.

## Source of truth

This repository is a **subtree-split mirror** of the Ruby SDK from our private monorepo `getnahook/nahook`. PRs filed directly here **cannot be merged** — the next subtree-push from the monorepo will force-overwrite this branch.

## What we welcome

- **Bug reports** — open a GitHub issue with: reproduction steps, gem version, Ruby version (`ruby --version`), OS.
- **Feature requests** — open an issue describing the use case and the API surface you'd want.
- **Small code suggestions** — paste a snippet in an issue and describe intent; we'll port it into the monorepo and credit you in the resulting commit.
- **Substantial patches** — email `support@nahook.com` first; we'll hand-port your change into the monorepo and credit you in the resulting commit.

## Local development

```bash
git clone https://github.com/getnahook/nahook-ruby
cd nahook-ruby
bundle install
gem build nahook.gemspec        # produces nahook-X.Y.Z.gem
ruby -Ilib -Itest -e "Dir.glob('test/**/*_test.rb').each { |f| require File.expand_path(f) }"
```

`nahook.gemspec` declares `s.required_ruby_version = ">= 3.0"`. SDK supports Ruby 3.0+.

(Note: per Ruby library convention, `Gemfile.lock` is gitignored — that's intentional so consumers can resolve transitives against their own dep ranges.)

### Code style

- minitest for tests
- Faraday for HTTP
- Match surrounding style; no required formatter

## License

By contributing, you agree your changes are released under the [MIT License](LICENSE).
