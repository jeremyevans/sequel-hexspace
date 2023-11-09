class Minitest::Spec
  if ENV['SEQUEL_ASYNC_THREAD_POOL'] || ENV['SEQUEL_ASYNC_THREAD_POOL_PREEMPT'] || ENV['SEQUEL_EAGER_ASYNC']
    use_async = true
    if ENV['SEQUEL_ASYNC_THREAD_POOL_PREEMPT']
      ::DB.opts[:preempt_async_thread] = true
    end
    ::DB.opts[:num_async_threads] = 12
    ::DB.extension :async_thread_pool

    if ENV['SEQUEL_EAGER_ASYNC']
      Sequel::Model.plugin :concurrent_eager_loading, :always=>true
    end
  end

  if use_async && DB.pool.pool_type == :threaded && (!DB.opts[:max_connections] || DB.opts[:max_connections] >= 4)
    def async?
      true
    end

    def wait
      yield.tap{}
    end
  else
    def async?
      false
    end

    def wait
      yield
    end
  end
end
