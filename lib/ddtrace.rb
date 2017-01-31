require 'ddtrace/monkey'
require 'ddtrace/pin'
require 'ddtrace/tracer'

# \Datadog global namespace that includes all tracing functionality for Tracer and Span classes.
module Datadog
  @tracer = Datadog::Tracer.new()

  # Default tracer that can be used as soon as +ddtrace+ is required:
  #
  #   require 'ddtrace'
  #
  #   span = Datadog.tracer.trace('web.request')
  #   span.finish()
  #
  # If you want to override the default tracer, the recommended way
  # is to "pin" your own tracer onto your traced component:
  #
  #   tracer = Datadog::Tracer.new
  #   pin = Datadog::Pin.get_from(mypatchcomponent)
  #   pin.tracer = tracer

  def self.tracer
    @tracer
  end
end

# Datadog auto instrumentation for frameworks
if defined?(Rails::VERSION)
  if Rails::VERSION::MAJOR.to_i >= 3
    require 'ddtrace/contrib/rails/framework'

    module Datadog
      # Run the auto instrumentation directly after the initialization of the application and
      # after the application initializers in config/initializers are run
      class Railtie < Rails::Railtie
        config.before_configuration do
          begin
            # We include 'redis-rails' here if it's available, doing it later
            # (typically in initialize callback) does not work, it does not
            # get loaded in the right context.
            require 'redis-rails'
            Datadog::Tracer.log.debug("'redis-rails' module found, Datadog 'redis-rails' integration is available")
          rescue LoadError
            Datadog::Tracer.log.debug("'redis-rails' module not found, Datadog 'redis-rails' integration is disabled")
          end

          Datadog::Monkey.patch_module(:redis)
        end

        # we do actions
        config.after_initialize do |app|
          Datadog::Contrib::Rails::Framework.configure(config: app.config)
          Datadog::Contrib::Rails::Framework.auto_instrument()
          Datadog::Contrib::Rails::Framework.auto_instrument_redis()
        end
      end
    end
  else
    logger = Logger.new(STDOUT)
    logger.warn 'Detected a Rails version < 3.x.'\
        'This version is not supported yet and the'\
        'auto-instrumentation for core components will be disabled.'
  end
end