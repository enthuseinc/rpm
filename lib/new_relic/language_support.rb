module NewRelic::LanguageSupport
  extend self
  
  module Control
    def self.included(base)
      # need to use syck rather than psych when possible
      if defined?(::YAML::ENGINE)
        if !NewRelic::LanguageSupport.using_engine?('jruby') &&
            (NewRelic::LanguageSupport.using_version?('1.9.1') ||
             NewRelic::LanguageSupport.using_version?('1.9.2'))
          base.class_eval do
            def load_newrelic_yml(*args)
              yamler = ::YAML::ENGINE.yamler
              ::YAML::ENGINE.yamler = 'syck'
              val = super
              ::YAML::ENGINE.yamler = yamler
              val
            end
          end
        end
      end
    end
  end
  
  module SynchronizedHash
    def self.included(base)
      # need to lock iteration of stats hash in 1.9.x
      if NewRelic::LanguageSupport.using_version?('1.9') ||
          NewRelic::LanguageSupport.using_engine?('jruby')
        base.class_eval do
          def each(*args, &block)
            @lock.synchronize { super }
          end
        end
      end
    end
  end
  
  @@forkable = nil
  
  def can_fork?
    # this is expensive to check, so we should only check once
    return @@forkable if @@forkable != nil

    if Process.respond_to?(:fork)
      # if this is not 1.9.2 or higher, we have to make sure
      @@forkable = ::RUBY_VERSION < '1.9.2' ? test_forkability : true
    else
      @@forkable = false
    end

    @@forkable
  end
  
  def using_engine?(engine)
    if defined?(::RUBY_ENGINE)
      ::RUBY_ENGINE == engine
    else
      engine == 'ruby'
    end
  end
  
  def using_version?(version)
    numbers = version.split('.')
    numbers == ::RUBY_VERSION.split('.')[0, numbers.size]
  end

  def test_forkability
    child = Process.fork { exit! }
    # calling wait here doesn't seem like it should necessary, but it seems to
    # resolve some weird edge cases with resque forking.
    Process.wait child
    true
  rescue NotImplementedError
    false
  end
end
