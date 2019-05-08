ALTER SYSTEM ALTER CONFIGURATION ('global.ini', 'SYSTEM') SET ('resource_tracking', 'service_thread_sampling_monitor_enabled') = 'true' WITH RECONFIGURE;

ALTER SYSTEM ALTER CONFIGURATION ('global.ini','SYSTEM') SET ('persistence','use_helper_threads_for_flush')='true' WITH RECONFIGURE;

ALTER SYSTEM ALTER CONFIGURATION ('global.ini','SYSTEM') SET ('persistence','use_helper_threads_for_flush')='false' WITH RECONFIGURE;

ALTER SYSTEM ALTER CONFIGURATION ('global.ini', 'SYSTEM') SET ('memorymanager', 'min_segment_size') = '32' WITH RECONFIGURE;
