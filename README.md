# SidekiqJobController

I bet there have been multiple occasions where an specific Job failures go out of control (by an introduced bug, or a broken dependency, external service or whatever) and you didn't have the ability to simply stop processing jobs for that job class or postpone their execution.

Sidekiq has a nice retry mechanism, but it is also too aggressive at first, every job wants to be retried very quickly, and sometimes you need to stop the job from being executed for a while.

Usually, the solution was to create a new Sidekiq queue in `sidekiq.yml`, deploy the change, which would give the ability to stop it, clear it, or whatever.
Or edit the job class to early return or avoid the error until you figure out what's going on.

That can work, but it can be slow, since you need to deploy the change to your infrastructure.

If you need something you can activate quickly, this Sidekiq Middleware is what you are looking for.

This middleware works for both Sidekiq workers and ActiveJob jobs.

## Installation

`bundle add sidekiq_job_controller`

In your `config/initializers/sidekiq.rb`:

```ruby
config.server_middleware do |chain|
  chain.add SidekiqJobController::ServerMiddleware
end
````

## Usage

In brief, we are adding a Sidekiq middleware that checks if a job/worker class has to be skipped all together, or re-queued for later execution.

This is useful to run in the console when a job is failing too much (or stressing the database too much), we can skip the execution or delay it for later.

**Example**: There’s a bug in production that causes `SomeJob` to fail many times per minute, causing a lot of errors in your error reporting tool and/or stressing your db.

You would do:

```ruby
SidekiqJobController::Controller.new(class_name: SomeJob).requeue_job!(45.minutes)
```

This will push every single `SomeJob` that Sidekiq wants to perform to be executed in 45 minutes instead of now.

Then you have 45 minutes to fix and deploy the changes.
If you take more than 45 minutes the jobs will be rescheduled for 45 more minutes, no problem.

Once you fix the problem and it’s in production, **`MAKE SURE`** to return the Job to its normal state:

```ruby
SidekiqJobController::Controller.new(class_name: SomeJob).resume_job!
```

If for any reason you need or prefer to just skip (discard, drop) the jobs execution (equivalent to return nil in the `perform`’s  first line of code) you would need to run:

```ruby
SidekiqJobController::Controller.new(class_name: SomeJob).skip_job!
```

You can always check the status of a job using:

```ruby
SidekiqJobController::Controller.new(class_name: SomeJob).status
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/circleco/sidekiq_job_controller. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/circleco/sidekiq_job_controller/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the SidekiqJobController project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/circleco/sidekiq_job_controller/blob/main/CODE_OF_CONDUCT.md).
