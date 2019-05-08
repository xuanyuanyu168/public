ALTER SYSTEM ALTER CONFIGURATION ('global.ini', 'SYSTEM') SET ('execution', 'max_concurrency') = '9' WITH RECONFIGURE;                                               

ALTER SYSTEM ALTER CONFIGURATION ('global.ini', 'SYSTEM') SET ('execution', 'max_concurrency_hint') = '5' WITH RECONFIGURE;                                           

ALTER SYSTEM ALTER CONFIGURATION ('global.ini', 'SYSTEM') SET ('parallel', 'num_cores') = '5' WITH RECONFIGURE;                                             

ALTER SYSTEM ALTER CONFIGURATION ('global.ini', 'SYSTEM') SET ('execution', 'default_statement_concurrency_limit') = '5' WITH RECONFIGURE;  

ALTER SYSTEM ALTER CONFIGURATION ('global.ini', 'SYSTEM') SET ('persistence', 'max_gc_parallelity') = '5' WITH RECONFIGURE;

ALTER SYSTEM ALTER CONFIGURATION ('global.ini', 'SYSTEM') SET ('resource_tracking', 'enable_tracking') = 'on' WITH RECONFIGURE;

ALTER SYSTEM ALTER CONFIGURATION ('global.ini', 'SYSTEM') SET ('resource_tracking', 'memory_tracking') = 'on' WITH RECONFIGURE;

ALTER SYSTEM ALTER CONFIGURATION ('global.ini', 'SYSTEM') SET ('resource_tracking', 'service_thread_sampling_monitor_thread_detail_enabled') = 'true' WITH RECONFIGURE;

ALTER SYSTEM ALTER CONFIGURATION ('global.ini', 'SYSTEM') SET ('memorymanager', 'statement_memory_limit_threshold') = '80' WITH RECONFIGURE;                                               

ALTER SYSTEM ALTER CONFIGURATION ('global.ini', 'SYSTEM') SET ('persistence', 'non_trans_cch_block_size') = '134217728' WITH RECONFIGURE;                                                         

ALTER SYSTEM ALTER CONFIGURATION ('indexserver.ini', 'SYSTEM') SET ('performance_analyzer', 'planviz_enable') = 'false' WITH RECONFIGURE;
