## checkpoint

```scala
 
spark中持久方法主要分为以下三种（：
persist()
cache()



/**
# persist()
persist()方法用于在rdd调用链路中缓存数据，避免重算。当某个算子需要重复利用时，可以调用该方法缓存rdd，加快运算。因为在spark执行流程中默认不会保存执行链路中的数据。

persist()还有一个带参重载函数，可以传入存储级别StorageLevel 

-- MEMORY_ONLY : 将 RDD 以反序列化 Java 对象的形式存储在 JVM 中。如果内存空间不够，部分数据分区将不再    缓存，在每次需要用到这些数据时重新进行计算。这是默认的级别。
-- MEMORY_AND_DISK : 将 RDD 以反序列化 Java 对象的形式存储在 JVM 中。如果内存空间不够，将未缓存的数    据分区存储到磁盘，在需要使用这些分区时从磁盘读取。
-- MEMORY_ONLY_SER : 将 RDD 以序列化的 Java 对象的形式进行存储（每个分区为一个 byte 数组）。这种方式    会比反序列化对象的方式节省很多空间，尤其是在使用 fast serializer时会节省更多的空间，但是在读取时会增    加 CPU 的计算负担。
-- MEMORY_AND_DISK_SER : 类似于 MEMORY_ONLY_SER ，但是溢出的分区会存储到磁盘，而不是在用到它们时重    新计算。
-- DISK_ONLY : 只在磁盘上缓存 RDD。
-- MEMORY_ONLY_2，MEMORY_AND_DISK_2，等等 : 与上面的级别功能相同，只不过每个分区在集群中两个节点上建    立副本。
-- OFF_HEAP（实验中）: 类似于 MEMORY_ONLY_SER ，但是将数据存储在 off-heap memory，这需要启动 off-      heap 内存。

当内存足够装下所有rdd可以使用MEMORY_ONLY，最高效；其次考虑MEMORY_ONLY_SER；再其次MEMORY_AND_DISK_SER

# cache()
可以理解为persist(StorageLevel.MEMORY_ONLY)

# checkpoint()
是懒加载的 只有真正的行动算子触发才会执行。一般来讲为了保证数据的安全性，该方法会将rdd执行两次，一次用于正常流程，一次用于真正的checkpoint。checkpoint的持久化路径一般设置为hdfs目录，由hdfs保证高可用和高可靠，所以checkpoint操作会切断血缘，无法根据依赖关系重做。
*** 所以一般checkpoint都会结合cache()/persist()来避免重复计算 ***
*/
# checkpoint()
/**
   * Mark this RDD for checkpointing. It will be saved to a file inside the checkpoint
   * directory set with `SparkContext#setCheckpointDir` and all references to its parent
   * RDDs will be removed. This function must be called before any job has been
   * executed on this RDD. It is strongly recommended that this RDD is persisted in
   * memory, otherwise saving it on a file will require recomputation.
   */


// 真正执行checkpoint逻辑的是doCheckpoint()方法：

  private[spark] def doCheckpoint(): Unit = {
    RDDOperationScope.withScope(sc, "checkpoint", allowNesting = false, ignoreParent = true) {
      if (!doCheckpointCalled) {
        doCheckpointCalled = true
// 如果定义checkpointAllMarkedAncestors为true，则会递归地执行父类的doCheckpoint()方法
        if (checkpointData.isDefined) { 
          if (checkpointAllMarkedAncestors) {
            dependencies.foreach(_.rdd.doCheckpoint())
          }
          // 保存checkpoint的数据 在内存中抽象为checkpointData类 
          checkpointData.get.checkpoint()
        } else {
          dependencies.foreach(_.rdd.doCheckpoint())
        }
      }
    }
  }


  

```

```scala
//########ReliableRDDCheckpointData伴生对象 定义了关于rdd存储路径和删除路径的方法#############

private[spark] object ReliableRDDCheckpointData extends Logging {

  /** Return the path of the directory to which this RDD's checkpoint data is written. */
  // 从sparkcontext中获取checkpointDir
  def checkpointPath(sc: SparkContext, rddId: Int): Option[Path] = {
    sc.checkpointDir.map { dir => new Path(dir, s"rdd-$rddId") }
  }

  /** Clean up the files associated with the checkpoint data for this RDD.
  
   用于清除生成的checkpoint文件
   
   需要的注意的是 #path.getFileSystem(sc.hadoopConfiguration)方法返回的是filesystem,
   点进去会来到这个方法
  org.apache.hadoop.fs.FileSystem#get(java.net.URI, org.apache.hadoop.conf.Configuration)
    --主要逻辑--
            String disableCacheName = String.format("fs.%s.impl.disable.cache", scheme);
            if (conf.getBoolean(disableCacheName, false)) {
            //如果这个参数设置为false则绕过缓存创建filesystem
                LOGGER.debug("Bypassing cache to create filesystem {}", uri);
                return createFileSystem(uri, conf);
            } else {
                //否则从缓存中获取
                return CACHE.get(uri, conf);
            }
   --主要逻辑--
    */
  def cleanCheckpoint(sc: SparkContext, rddId: Int): Unit = {
    checkpointPath(sc, rddId).foreach { path =>
      path.getFileSystem(sc.hadoopConfiguration).delete(path, true)
    }
  }
}

//#################ReliableRDDCheckpointData类 定义了关于存储rdd相关的方法###############

/**
   * Materialize this RDD and write its content to a reliable DFS.
   * This is called immediately after the first action invoked on this RDD has completed.
   
   */
  protected override def doCheckpoint(): CheckpointRDD[T] = {
    // 真正执行存储操作的是writeRDDToCheckpointDirectory方法
    val newRDD = ReliableCheckpointRDD.writeRDDToCheckpointDirectory(rdd, cpDir)

    // Optionally clean our checkpoint files if the reference is out of scope
    // 默认checkpoint是不会认为删除的，当(1)设置CLEANER_REFERENCE_TRACKING_CLEAN_CHECKPOINTS为true时，(2)且没有任何引用指向该rdd,(3)系统触发垃圾回收（源码层面会定时执行system.gc()）时会将该checkpoint文件清除。
    if (rdd.conf.get(CLEANER_REFERENCE_TRACKING_CLEAN_CHECKPOINTS)) {
      rdd.context.cleaner.foreach { cleaner =>
        cleaner.registerRDDCheckpointDataForCleanup(newRDD, rdd.id)
      }
    }

    logInfo(s"Done checkpointing RDD ${rdd.id} to $cpDir, new parent is RDD ${newRDD.id}")
      //返回的newRDD可以理解为该checkpoint文件在内存中的一份映射
    newRDD
  }


//#################ReliableCheckpointRDD.writeRDDToCheckpointDirectory###############
//#################真正执行存储操作的是writeRDDToCheckpointDirectory方法###############
/**
   * Write RDD to checkpoint files and return a ReliableCheckpointRDD representing the RDD.
   */
  def writeRDDToCheckpointDirectory[T: ClassTag](
      originalRDD: RDD[T],
      checkpointDir: String,
      blockSize: Int = -1): ReliableCheckpointRDD[T] = {
    val checkpointStartTimeNs = System.nanoTime()

    val sc = originalRDD.sparkContext

    // Create the output path for the checkpoint
    // 创建指定的目录，一般是hdfs目录
    val checkpointDirPath = new Path(checkpointDir)
    val fs = checkpointDirPath.getFileSystem(sc.hadoopConfiguration)
    if (!fs.mkdirs(checkpointDirPath)) {
      throw new SparkException(s"Failed to create checkpoint path $checkpointDirPath")
    }

    // Save to file, and reload it as an RDD
    //将序列化的hadoopConfiguration当成广播变量进行共享
    val broadcastedConf = sc.broadcast(
      new SerializableConfiguration(sc.hadoopConfiguration))
    // 会再次执行一遍计算RDD，代价昂贵，所以一般和persist()/cache()结合使用，减少重复计算
    // runjob的执行 提交到不同节点进行执行，如果是本地模式，则会用线程模拟
    //具体job执行过程参见下文
    sc.runJob(originalRDD,
      writePartitionToCheckpointFile[T](checkpointDirPath.toString, broadcastedConf) _)
	//如果partitoner非空 则同样需要需要将分区器序列化并存盘
    if (originalRDD.partitioner.nonEmpty) {
      writePartitionerToCheckpointDir(sc, originalRDD.partitioner.get, checkpointDirPath)
    }

    val checkpointDurationMs =
      TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - checkpointStartTimeNs)
    logInfo(s"Checkpointing took $checkpointDurationMs ms.")

    val newRDD = new ReliableCheckpointRDD[T](
      sc, checkpointDirPath.toString, originalRDD.partitioner)
    if (newRDD.partitions.length != originalRDD.partitions.length) {
      throw new SparkException(
        "Checkpoint RDD has a different number of partitions from original RDD. Original " +
          s"RDD [ID: ${originalRDD.id}, num of partitions: ${originalRDD.partitions.length}]; " +
          s"Checkpoint RDD [ID: ${newRDD.id}, num of partitions: " +
          s"${newRDD.partitions.length}].")
    }
    newRDD
  }


// =====org.apache.spark.rdd.ReliableCheckpointRDD#writePartitionToCheckpointFile======
  /**
   * Write an RDD partition's data to a checkpoint file.
   */
  def writePartitionToCheckpointFile[T: ClassTag](
      path: String,
      broadcastedConf: Broadcast[SerializableConfiguration],
      blockSize: Int = -1)(ctx: TaskContext, iterator: Iterator[T]): Unit = {
    val env = SparkEnv.get
    val outputDir = new Path(path)
    val fs = outputDir.getFileSystem(broadcastedConf.value.value)
	//得到真正存储checkpoint数据的目录：原来指定的路径 + uuid +rddId + partitionId(五位)
    val finalOutputName = ReliableCheckpointRDD.checkpointFileName(ctx.partitionId())
    val finalOutputPath = new Path(outputDir, finalOutputName)
    val tempOutputPath =
      new Path(outputDir, s".$finalOutputName-attempt-${ctx.attemptNumber()}")
	// 默认的块大小 65536
    val bufferSize = env.conf.get(BUFFER_SIZE)

    val fileOutputStream = if (blockSize < 0) {
      //得到FSDataOutputStream overwrite:false bufferSize:65536
      //文件权限 用户（u），组（g），其他（o）
      //默认是 111-100-011 rwx- r-- -wx
      val fileStream = fs.create(tempOutputPath, false, bufferSize)
      if (env.conf.get(CHECKPOINT_COMPRESS)) {
        // 判断是否开启压缩 开启则进行如下操作
        CompressionCodec.createCodec(env.conf).compressedOutputStream(fileStream)
      } else {
        fileStream
      }
    } else {
      // This is mainly for testing purpose
      fs.create(tempOutputPath, false, bufferSize,
        fs.getDefaultReplication(fs.getWorkingDirectory), blockSize)
    }
    val serializer = env.serializer.newInstance()
      // 将得到的fileOutputStream包装成序列化输出流
      // 默认使用`org.apache.spark.serializer.JavaSerializer`进行序列化
    val serializeStream = serializer.serializeStream(fileOutputStream)
    Utils.tryWithSafeFinally {
        //最后调用java.io.ObjectOutputStream#writeObject进行真正的写磁盘
      serializeStream.writeAll(iterator)
    } {
      serializeStream.close()
    }

    if (!fs.rename(tempOutputPath, finalOutputPath)) {
      if (!fs.exists(finalOutputPath)) {
        logInfo(s"Deleting tempOutputPath $tempOutputPath")
        fs.delete(tempOutputPath, false)
        throw new IOException("Checkpoint failed: failed to save output of task: " +
          s"${ctx.attemptNumber()} and final output path does not exist: $finalOutputPath")
      } else {
        // Some other copy of this task must've finished before us and renamed it
        logInfo(s"Final output path $finalOutputPath already exists; not overwriting it")
        if (!fs.delete(tempOutputPath, false)) {
          logWarning(s"Error deleting ${tempOutputPath}")
        }
      }
    }
  }
```



## persist

```scala
  /**
   * Set this RDD's storage level to persist its values across operations after the first time it is computed. This can only be used to assign a new storage level if the RDD does not have a storage level set yet. Local checkpointing is an exception.
   */
  def persist(newLevel: StorageLevel): this.type = {
    if (isLocallyCheckpointed) {
// This means the user previously called localCheckpoint(), which should have already
// marked this RDD for persisting. Here we should override the old storage level with
// one that is explicitly requested by the user (after adapting it to use disk).
      persist(LocalRDDCheckpointData.transformStorageLevel(newLevel), allowOverride = true)
    } else {
      // 这是主要分支
      persist(newLevel, allowOverride = false)
    }
  }


// ##### org.apache.spark.rdd.RDD#persist  #####

  private def persist(newLevel: StorageLevel, allowOverride: Boolean): this.type = {
    // TODO: Handle changes of StorageLevel
    if (storageLevel != StorageLevel.NONE && newLevel != storageLevel && !allowOverride) {
      throw new UnsupportedOperationException(
        "Cannot change storage level of an RDD after it was already assigned a level")
    }
    // If this is the first time this RDD is marked for persisting, register it
    // with the SparkContext for cleanups and accounting. Do this only once.
    if (storageLevel == StorageLevel.NONE) {
      sc.cleaner.foreach(_.registerRDDForCleanup(this))  // 注册 主要用于后续垃圾回收
      sc.persistRDD(this) //真正将RDD persist
    }
    storageLevel = newLevel
    this
  }
// ##### org.apache.spark.SparkContext#persistRDD #####
  /**
   * Register an RDD to be persisted in memory and/or disk storage
   */
  private[spark] def persistRDD(rdd: RDD[_]): Unit = {
    // 放入到一个map(sparkContext中的一个属性--persistentRdds)中
    // 该map的值是WeakReference 也就是 容易被垃圾回收
    // 可以看出这里只是把数据放到一个map中，并没有进行真正地存储，懒加载，
    // 在遇到行动算子触发任务执行，当需要磁盘溢写的时候 
    // 才会根据设置的存储等级来进行磁盘溢写或者直接丢弃
    persistentRdds(rdd.id) = rdd 
  }
```



## 阶段划分和任务调度

```scala
################ org.apache.spark.SparkContext#runJob #############################
//该方法是真正地将任务进行阶段划分，并且在执行完job后，执行 rdd.doCheckpoint()
  def runJob[T, U: ClassTag](
      rdd: RDD[T],
      func: (TaskContext, Iterator[T]) => U,
      partitions: Seq[Int],
      resultHandler: (Int, U) => Unit): Unit = {
    if (stopped.get()) {
      throw new IllegalStateException("SparkContext has been shutdown")
    }
    val callSite = getCallSite
    val cleanedFunc = clean(func)
    logInfo("Starting job: " + callSite.shortForm)
    if (conf.getBoolean("spark.logLineage", false)) {
      logInfo("RDD's recursive dependencies:\n" + rdd.toDebugString)
    }
    // 真正执行阶段的划分，并且分发任务到各执行节点
    dagScheduler.runJob(rdd, cleanedFunc, partitions, callSite, resultHandler, localProperties.get)
    progressBar.foreach(_.finishAll())
    rdd.doCheckpoint() // 我们之前设置的checkpoint（）方法在此处执行
  }

############# org.apache.spark.scheduler.DAGScheduler#runJob ####################
// 该方法真正地进行阶段的划分
  def runJob[T, U](
      rdd: RDD[T],
      func: (TaskContext, Iterator[T]) => U,
      partitions: Seq[Int],
      callSite: CallSite,
      resultHandler: (Int, U) => Unit,
      properties: Properties): Unit = {
    val start = System.nanoTime
    
    val waiter = submitJob(rdd, func, partitions, callSite, resultHandler, properties)
      
    //阻塞该线程，等待waiter执行完毕
    //因为在submitJob中会将任务放入一个阻塞队列中去，会有一个单独的线程消费该队列中的任务
    //只有当所有任务完成（成功或者异常结束）waiter才会返回，继续执行后面的流程
    ThreadUtils.awaitReady(waiter.completionFuture, Duration.Inf)
    //判断提交的任务是否完成
    waiter.completionFuture.value.get match {
      case scala.util.Success(_) =>
        logInfo("Job %d finished: %s, took %f s".format
          (waiter.jobId, callSite.shortForm, (System.nanoTime - start) / 1e9))
      case scala.util.Failure(exception) =>
        logInfo("Job %d failed: %s, took %f s".format
          (waiter.jobId, callSite.shortForm, (System.nanoTime - start) / 1e9))
        // SPARK-8644: Include user stack trace in exceptions coming from DAGScheduler.
        val callerStackTrace = Thread.currentThread().getStackTrace.tail
        exception.setStackTrace(exception.getStackTrace ++ callerStackTrace)
        throw exception
    }
  }
############# org.apache.spark.scheduler.DAGScheduler#submitJob ####################
 val waiter = submitJob(rdd, func, partitions, callSite, resultHandler, properties)
############# org.apache.spark.scheduler.DAGScheduler#submitJob ####################

def submitJob[T, U](
      rdd: RDD[T],
      func: (TaskContext, Iterator[T]) => U,
      partitions: Seq[Int],
      callSite: CallSite,
      resultHandler: (Int, U) => Unit,
      properties: Properties): JobWaiter[U] = {
    // Check to make sure we are not launching a task on a partition that does not exist.
    val maxPartitions = rdd.partitions.length
    partitions.find(p => p >= maxPartitions || p < 0).foreach { p =>
      throw new IllegalArgumentException(
        "Attempting to access a non-existent partition: " + p + ". " +
          "Total number of partitions: " + maxPartitions)
    }
	//获得原子类自增integer，作为jobId
    val jobId = nextJobId.getAndIncrement()
    //如果分区为空 快速完成
    if (partitions.isEmpty) {
      val clonedProperties = Utils.cloneProperties(properties)
      if (sc.getLocalProperty(SparkContext.SPARK_JOB_DESCRIPTION) == null) {
        clonedProperties.setProperty(SparkContext.SPARK_JOB_DESCRIPTION, callSite.shortForm)
      }
      val time = clock.getTimeMillis()
      // 将事件event post到监听队列中去，等待消费 ==> 主要适用于网页端监控使用
      listenerBus.post(
        SparkListenerJobStart(jobId, time, Seq.empty, clonedProperties))
      listenerBus.post(
        SparkListenerJobEnd(jobId, time, JobSucceeded))
      // Return immediately if the job is running 0 tasks
      return new JobWaiter[U](this, jobId, 0, resultHandler)
    }

    assert(partitions.nonEmpty)
    val func2 = func.asInstanceOf[(TaskContext, Iterator[_]) => _]
    val waiter = new JobWaiter[U](this, jobId, partitions.size, resultHandler)
 //会将任务提交给放到一个LinkedBlockingDeque当中去，会有一个叫eventThread的线程消费该阻塞队列中的事件
    eventProcessLoop.post(JobSubmitted(
      jobId, rdd, func2, partitions.toArray, callSite, waiter,
      Utils.cloneProperties(properties)))
    //返回一个JobWaiter，用于等待所有提交的任务完成
    waiter
  }

```

```scala
/**
 * An object that waits for a DAGScheduler job to complete. As tasks finish, it passes their results to the given handler function.
 */

// 主要用于等待提交的所有任务完成
private[spark] class JobWaiter[T](
    dagScheduler: DAGScheduler,
    val jobId: Int,
    totalTasks: Int,
    resultHandler: (Int, T) => Unit)  //任务完成时需要执行的函数
  extends JobListener with Logging {

  private val finishedTasks = new AtomicInteger(0)
  // If the job is finished, this will be its result. In the case of 0 task jobs (e.g. zero
  // partition RDDs), we set the jobResult directly to JobSucceeded.
  private val jobPromise: Promise[Unit] =
    if (totalTasks == 0) Promise.successful(()) else Promise()

  def jobFinished: Boolean = jobPromise.isCompleted

  def completionFuture: Future[Unit] = jobPromise.future

  /**
   * Sends a signal to the DAGScheduler to cancel the job. The cancellation itself is handled asynchronously. After the low level scheduler cancels all the tasks belonging to this job, it will fail this job with a SparkException.
*/
  def cancel(): Unit = {
    dagScheduler.cancelJob(jobId, None)
  }

  override def taskSucceeded(index: Int, result: Any): Unit = {
    // resultHandler call must be synchronized in case resultHandler itself is not thread safe.
    synchronized {
      resultHandler(index, result.asInstanceOf[T])
    }
    if (finishedTasks.incrementAndGet() == totalTasks) { // 当完成的任务数与传递的任务数一致时
      jobPromise.success(())
    }
  }

  override def jobFailed(exception: Exception): Unit = {
    if (!jobPromise.tryFailure(exception)) {
      logWarning("Ignore failure", exception)
    }
  }
}
```

```scala
// ######################org.apache.spark.util.EventLoop#post############################
/* 在org.apache.spark.scheduler.DAGScheduler#eventProcessLoop类中调用post()方法，即：
    eventProcessLoop.post(JobSubmitted(
      jobId, rdd, func2, partitions.toArray, callSite, waiter,
      Utils.cloneProperties(properties)))
实际上执行的是org.apache.spark.util.EventLoop#post
*/
// post方法的逻辑如下：
// Put the event into the event queue. The event thread will process it later.
  def post(event: E): Unit = {
    if (!stopped.get) {
        //post成功的前提是该线程已经启动
      if (eventThread.isAlive) {
        // LinkedBlockingDeque
        eventQueue.put(event)
      } else {
        onError(new IllegalStateException(s"$name has already been stopped accidentally."))
      }
    }
  }
// 那么eventThread线程在什么时候会启动呢？
// org.apache.spark.util.EventLoop#start

  def start(): Unit = {
    if (stopped.get) {
      throw new IllegalStateException(name + " has already been stopped")
    }
    // Call onStart before starting the event thread to make sure it happens before              onReceive
    //子类org.apache.spark.scheduler.DAGSchedulerEventProcessLoop针对该方法暂时未做任何实现，         空方法，方便后期扩展
    onStart() 
    //启动eventThread线程，便会开始执行里面的run()方法
    eventThread.start()
  }

// run()实际做的便是从eventQueue（LinkedBlockingDeque）取数据-->调用onreceive方法

override def run(): Unit = {
      try {
        while (!stopped.get) {
          val event = eventQueue.take() //从eventQueue(LinkedBlockingDeque)取数据 为空则阻塞
          try {
            onReceive(event) //该方法由子类DAGSchedulerEventProcessLoop实现
          } catch {
            case NonFatal(e) =>
              try {
                onError(e)
              } catch {
                case NonFatal(e) => logError("Unexpected error in " + name, e)
              }
          }
        }
      } catch {
        case ie: InterruptedException => // exit even if eventQueue is not empty
        case NonFatal(e) => logError("Unexpected error in " + name, e)
      }
    }
// 子类DAGSchedulerEventProcessLoop onReceive(event)实现会实际调用doOnReceive方法，根据不同的事	件，调用不同的处理函数进行处理
  private def doOnReceive(event: DAGSchedulerEvent): Unit = event match {
      
    case JobSubmitted(jobId, rdd, func, partitions, callSite, listener, properties) =>
      dagScheduler.handleJobSubmitted(jobId, rdd, func, partitions, callSite, listener, properties)

    case MapStageSubmitted(jobId, dependency, callSite, listener, properties) =>
      dagScheduler.handleMapStageSubmitted(jobId, dependency, callSite, listener, properties)

    case StageCancelled(stageId, reason) =>
      dagScheduler.handleStageCancellation(stageId, reason)

    case JobCancelled(jobId, reason) =>
      dagScheduler.handleJobCancellation(jobId, reason)

    case JobGroupCancelled(groupId) =>
      dagScheduler.handleJobGroupCancelled(groupId)

    case AllJobsCancelled =>
      dagScheduler.doCancelAllJobs()

    case ExecutorAdded(execId, host) =>
      dagScheduler.handleExecutorAdded(execId, host)

    case ExecutorLost(execId, reason) =>
      val workerLost = reason match {
        case SlaveLost(_, true) => true
        case _ => false
      }
      dagScheduler.handleExecutorLost(execId, workerLost)

    case WorkerRemoved(workerId, host, message) =>
      dagScheduler.handleWorkerRemoved(workerId, host, message)

    case BeginEvent(task, taskInfo) =>
      dagScheduler.handleBeginEvent(task, taskInfo)

    case SpeculativeTaskSubmitted(task) =>
      dagScheduler.handleSpeculativeTaskSubmitted(task)

    case GettingResultEvent(taskInfo) =>
      dagScheduler.handleGetTaskResult(taskInfo)

    case completion: CompletionEvent =>
      dagScheduler.handleTaskCompletion(completion)

    case TaskSetFailed(taskSet, reason, exception) =>
      dagScheduler.handleTaskSetFailed(taskSet, reason, exception)

    case ResubmitFailedStages =>
      dagScheduler.resubmitFailedStages()
  }

//下面分析 case JobSubmitted(jobId, rdd, func, partitions, callSite, listener, properties)
//会如何处理？
// 任务已经提交，具体的处理逻辑在方法：
// org.apache.spark.scheduler.DAGScheduler#handleJobSubmitted

private[scheduler] def handleJobSubmitted(jobId: Int,
      finalRDD: RDD[_],
      func: (TaskContext, Iterator[_]) => _,
      partitions: Array[Int],
      callSite: CallSite,
      listener: JobListener,
      properties: Properties): Unit = {
    var finalStage: ResultStage = null
    try {
      // New stage creation may throw an exception if, for example, jobs are run on a
      // HadoopRDD whose underlying HDFS files have been deleted.
   // - ****************************得到finalStagfe*************** ****************** -
      | finalStage = createResultStage(finalRDD, func, partitions, jobId, callSite)   |
   // - **************************************************************************** -
    } catch {
      case e: BarrierJobSlotsNumberCheckFailed =>
        // If jobId doesn't exist in the map, Scala coverts its value null to 0: Int automatically.
        val numCheckFailures = barrierJobIdToNumTasksCheckFailures.compute(jobId,
          (_: Int, value: Int) => value + 1)

        logWarning(s"Barrier stage in job $jobId requires ${e.requiredConcurrentTasks} slots, " +
          s"but only ${e.maxConcurrentTasks} are available. " +
          s"Will retry up to ${maxFailureNumTasksCheck - numCheckFailures + 1} more times")
		// 当空闲的slot数量不能够满足当前任务时，或加入到单线程调度线程池中，延迟一定时间执行
        if (numCheckFailures <= maxFailureNumTasksCheck) {
          messageScheduler.schedule(
            new Runnable {
              override def run(): Unit = eventProcessLoop.post(JobSubmitted(jobId, finalRDD, func, partitions, callSite, listener, properties))
            },
            timeIntervalNumTasksCheck,
            TimeUnit.SECONDS
          )
          return
        } else {
          // Job failed, clear internal data.
          barrierJobIdToNumTasksCheckFailures.remove(jobId)
          // 这个listener就是上文提到的JobWaiter，当任务失败时，调用jobFailed函数使得内部统计的                  finisedJod数+1 当等于task总数时，该任务结束
          listener.jobFailed(e)
          return
        }

      case e: Exception =>
        logWarning("Creating new stage failed due to exception - job: " + jobId, e)
        listener.jobFailed(e)
        return
    }
    // Job submitted, clear internal data.
    barrierJobIdToNumTasksCheckFailures.remove(jobId)

    val job = new ActiveJob(jobId, finalStage, callSite, listener, properties)
    clearCacheLocs()
    logInfo("Got job %s (%s) with %d output partitions".format(
      job.jobId, callSite.shortForm, partitions.length))
    logInfo("Final stage: " + finalStage + " (" + finalStage.name + ")")
    logInfo("Parents of final stage: " + finalStage.parents)
    logInfo("Missing parents: " + getMissingParentStages(finalStage))

    val jobSubmissionTime = clock.getTimeMillis()
    jobIdToActiveJob(jobId) = job
    activeJobs += job
    finalStage.setActiveJob(job)
    val stageIds = jobIdToStageIds(jobId).toArray
    val stageInfos = stageIds.flatMap(id => stageIdToStage.get(id).map(_.latestInfo))
    // 将事件异步投递给监听器，达到实时刷新UI界面数据的效果
    listenerBus.post(
      SparkListenerJobStart(job.jobId, jobSubmissionTime, stageInfos, properties))
    // 提交 阶段
    submitStage(finalStage)
  }

```

```scala
   // - ****************************得到finalStagfe*************** ****************** -
      | finalStage = createResultStage(finalRDD, func, partitions, jobId, callSite)   |
   // - **************************************************************************** -
具体逻辑如下：
// ##################org.apache.spark.scheduler.DAGScheduler#createResultStage#############

  private def createResultStage(
      rdd: RDD[_],
      func: (TaskContext, Iterator[_]) => _,
      partitions: Array[Int],
      jobId: Int,
      callSite: CallSite): ResultStage = {
    checkBarrierStageWithDynamicAllocation(rdd)
    checkBarrierStageWithNumSlots(rdd)
    checkBarrierStageWithRDDChainPattern(rdd, partitions.toSet.size)
    val parents = getOrCreateParentStages(rdd, jobId)  // 关键在于 得到或创建父阶段
    val id = nextStageId.getAndIncrement()
    val stage = new ResultStage(id, rdd, func, partitions, parents, jobId, callSite)
    stageIdToStage(id) = stage
    updateJobIdStageIdMaps(jobId, stage)
    stage
  }
// 本质上调用了下面的方法
##################org.apache.spark.scheduler.DAGScheduler#getOrCreateParentStages########

  private def getOrCreateParentStages(rdd: RDD[_], firstJobId: Int): List[Stage] = {
    getShuffleDependencies(rdd).map { shuffleDep =>
      // 基于shuffle依赖划分阶段，有多少个shuffle便会产生多少个阶段
      getOrCreateShuffleMapStage(shuffleDep, firstJobId)
    }.toList
  }
```



```scala
// ##################org.apache.spark.scheduler.DAGScheduler#submitStage#################
//真正开始提交阶段了  
/** Submits stage, but first recursively submits any missing parents. */

  private def submitStage(stage: Stage): Unit = {
    val jobId = activeJobForStage(stage)
    if (jobId.isDefined) {
      logDebug(s"submitStage($stage (name=${stage.name};" +
        s"jobs=${stage.jobIds.toSeq.sorted.mkString(",")}))")
      if (!waitingStages(stage) && !runningStages(stage) && !failedStages(stage)) {
        
        // 尝试获得父阶段（因为之前的获取阶段只会获取最近的suffle依赖，可能没有追溯到最起始的rdd）
        val missing = getMissingParentStages(stage).sortBy(_.id)
        logDebug("missing: " + missing)
        if (missing.isEmpty) {
          logInfo("Submitting " + stage + " (" + stage.rdd + "), which has no missing parents")
          // 如果没有父阶段，则直接提交该阶段
          submitMissingTasks(stage, jobId.get)
        } else {
          // 如果有父阶段，则将所有的父阶段提交，自己则加入的waitingStages（HashSet）
          for (parent <- missing) {
            submitStage(parent)
          }
          waitingStages += stage
        }
      }
    } else {
      abortStage(stage, "No active job for stage " + stage.id, None)
    }
  }
  

// ############# org.apache.spark.scheduler.DAGScheduler#submitMissingTasks #########
当没有父阶段的时候，调用下面的函数
/** Called when stage's parents are available and we can now do its task. */
  private def submitMissingTasks(stage: Stage, jobId: Int): Unit = {
    logDebug("submitMissingTasks(" + stage + ")")

    // Before find missing partition, do the intermediate state clean work first.
    // The operation here can make sure for the partially completed intermediate stage,
    // `findMissingPartitions()` returns all partitions every time.
    stage match {
      case sms: ShuffleMapStage if stage.isIndeterminate && !sms.isAvailable =>
        mapOutputTracker.unregisterAllMapOutput(sms.shuffleDep.shuffleId)
      case _ =>
    }

    // Figure out the indexes of partition ids to compute.
    val partitionsToCompute: Seq[Int] = stage.findMissingPartitions()

    // Use the scheduling pool, job group, description, etc. from an ActiveJob associated
    // with this Stage
    val properties = jobIdToActiveJob(jobId).properties

    runningStages += stage //加入运行 的 stages(HashSet)
    // SparkListenerStageSubmitted should be posted before testing whether tasks are
    // serializable. If tasks are not serializable, a SparkListenerStageCompleted event
    // will be posted, which should always come after a corresponding SparkListenerStageSubmitted
    // event.
    stage match {
      case s: ShuffleMapStage =>
        outputCommitCoordinator.stageStart(stage = s.id, maxPartitionId = s.numPartitions - 1)
      case s: ResultStage =>
        outputCommitCoordinator.stageStart(
          stage = s.id, maxPartitionId = s.rdd.partitions.length - 1)
    }
    val taskIdToLocations: Map[Int, Seq[TaskLocation]] = try {
      stage match {
        case s: ShuffleMapStage =>
          partitionsToCompute.map { id => (id, getPreferredLocs(stage.rdd, id))}.toMap
        case s: ResultStage =>
          partitionsToCompute.map { id =>
            val p = s.partitions(id)
            (id, getPreferredLocs(stage.rdd, p))
          }.toMap
      }
    } catch {
      case NonFatal(e) =>
        stage.makeNewStageAttempt(partitionsToCompute.size)
        listenerBus.post(SparkListenerStageSubmitted(stage.latestInfo, properties))
        abortStage(stage, s"Task creation failed: $e\n${Utils.exceptionString(e)}", Some(e))
        runningStages -= stage
        return
    }

    stage.makeNewStageAttempt(partitionsToCompute.size, taskIdToLocations.values.toSeq)

    // If there are tasks to execute, record the submission time of the stage. Otherwise,
    // post the even without the submission time, which indicates that this stage was
    // skipped.
    if (partitionsToCompute.nonEmpty) {
      stage.latestInfo.submissionTime = Some(clock.getTimeMillis())
    }
    // 将事件异步投递给监听器，达到实时刷新UI界面数据的效果
    listenerBus.post(SparkListenerStageSubmitted(stage.latestInfo, properties))

    // TODO: Maybe we can keep the taskBinary in Stage to avoid serializing it multiple times.
    // Broadcasted binary for the task, used to dispatch tasks to executors. Note that we broadcast
    // the serialized copy of the RDD and for each task we will deserialize it, which means each
    // task gets a different copy of the RDD. This provides stronger isolation between tasks that
    // might modify state of objects referenced in their closures. This is necessary in Hadoop
    // where the JobConf/Configuration object is not thread-safe.
    var taskBinary: Broadcast[Array[Byte]] = null
    var partitions: Array[Partition] = null
    try {
      // 对于ShuffleMapTask, 序列化和广播 (rdd, shuffleDep).
      // 对于ResultTask, 序列化和广播 (rdd, func).
      var taskBinaryBytes: Array[Byte] = null
      // taskBinaryBytes and partitions are both effected by the checkpoint status. We need this synchronization in case another concurrent job is checkpointing this RDD, so we get a consistent view of both variables.
      RDDCheckpointData.synchronized {
        taskBinaryBytes = stage match {
          case stage: ShuffleMapStage =>
            JavaUtils.bufferToArray(
              closureSerializer.serialize((stage.rdd, stage.shuffleDep): AnyRef))
          case stage: ResultStage =>
            JavaUtils.bufferToArray(closureSerializer.serialize((stage.rdd, stage.func): AnyRef))
        }

        partitions = stage.rdd.partitions
      }
	  // 检查序列化的task是否长度是否超过限制：> 1000 KiB 告警
      if (taskBinaryBytes.length > TaskSetManager.TASK_SIZE_TO_WARN_KIB * 1024) {
        logWarning(s"Broadcasting large task binary with size " +
          s"${Utils.bytesToString(taskBinaryBytes.length)}")
      }
      taskBinary = sc.broadcast(taskBinaryBytes) //进行广播
    } catch {
      // In the case of a failure during serialization, abort the stage.
      //闭包检测的时候发现不能序列化
      case e: NotSerializableException =>
        abortStage(stage, "Task not serializable: " + e.toString, Some(e))
        runningStages -= stage

        // Abort execution
        return
      case e: Throwable =>
        abortStage(stage, s"Task serialization failed: $e\n${Utils.exceptionString(e)}", Some(e))
        runningStages -= stage

        // Abort execution
        return
    }

    val tasks: Seq[Task[_]] = try {
      val serializedTaskMetrics = closureSerializer.serialize(stage.latestInfo.taskMetrics).array()
      stage match {
        case stage: ShuffleMapStage =>
          stage.pendingPartitions.clear()
          partitionsToCompute.map { id =>
            val locs = taskIdToLocations(id)
            val part = partitions(id)
            stage.pendingPartitions += id
            new ShuffleMapTask(stage.id, stage.latestInfo.attemptNumber,
              taskBinary, part, locs, properties, serializedTaskMetrics, Option(jobId),
              Option(sc.applicationId), sc.applicationAttemptId, stage.rdd.isBarrier())
          }

        case stage: ResultStage =>
          partitionsToCompute.map { id =>
            val p: Int = stage.partitions(id)
            val part = partitions(p)
            val locs = taskIdToLocations(id)
            new ResultTask(stage.id, stage.latestInfo.attemptNumber,
              taskBinary, part, locs, id, properties, serializedTaskMetrics,
              Option(jobId), Option(sc.applicationId), sc.applicationAttemptId,
              stage.rdd.isBarrier())
          }
      }
    } catch {
      case NonFatal(e) =>
        abortStage(stage, s"Task creation failed: $e\n${Utils.exceptionString(e)}", Some(e))
        runningStages -= stage
        return
    }

    if (tasks.nonEmpty) {
      logInfo(s"Submitting ${tasks.size} missing tasks from $stage (${stage.rdd}) (first 15 " +
        s"tasks are for partitions ${tasks.take(15).map(_.partitionId)})")
      // **** 通过任务调度器提交序列化的task ****
      taskScheduler.submitTasks(new TaskSet(
        tasks.toArray, stage.id, stage.latestInfo.attemptNumber, jobId, properties))
    } else {
      // Because we posted SparkListenerStageSubmitted earlier, we should mark
      // the stage as completed here in case there are no tasks to run
      markStageAsFinished(stage, None)

      stage match {
        case stage: ShuffleMapStage =>
          logDebug(s"Stage ${stage} is actually done; " +
              s"(available: ${stage.isAvailable}," +
              s"available outputs: ${stage.numAvailableOutputs}," +
              s"partitions: ${stage.numPartitions})")
          markMapStageJobsAsFinished(stage)
        case stage : ResultStage =>
          logDebug(s"Stage ${stage} is actually done; (partitions: ${stage.numPartitions})")
      }
      //提交子阶段，也是就是之前加入到waitingStages的stage
      submitWaitingChildStages(stage)
    }
  }
```

```scala
// #############org.apache.spark.scheduler.local.LocalSchedulerBackend##################
/**
 * Calls to [[LocalSchedulerBackend]] are all serialized through LocalEndpoint. Using an
 * RpcEndpoint makes the calls on [[LocalSchedulerBackend]] asynchronous, which is necessary
 * to prevent deadlock between [[LocalSchedulerBackend]] and the [[TaskSchedulerImpl]].
 

 */
private[spark] class LocalEndpoint( // 可以理解为rpc的提供方，供任务调度后台进行调用
    override val rpcEnv: RpcEnv,   // 根据收到的消息类型完成更新状态、执行任务、杀死executor等动作
    userClassPath: Seq[URL],
    scheduler: TaskSchedulerImpl,
    executorBackend: LocalSchedulerBackend,
    private val totalCores: Int)
  extends ThreadSafeRpcEndpoint with Logging {

  private var freeCores = totalCores //可分配的cpu核数

  val localExecutorId = SparkContext.DRIVER_IDENTIFIER
  val localExecutorHostname = Utils.localCanonicalHostName()

  // local mode doesn't support extra resources like GPUs right now
  private val executor = new Executor(
    localExecutorId, localExecutorHostname, SparkEnv.get, userClassPath, isLocal = true,
    resources = Map.empty[String, ResourceInformation])

  override def receive: PartialFunction[Any, Unit] = {
    case ReviveOffers =>
      reviveOffers() //放到executor中执行

    case StatusUpdate(taskId, state, serializedData) => //更新状态，更新cpu可用数量
      scheduler.statusUpdate(taskId, state, serializedData)
      if (TaskState.isFinished(state)) {
        freeCores += scheduler.CPUS_PER_TASK
        reviveOffers()
      }

    case KillTask(taskId, interruptThread, reason) =>
      executor.killTask(taskId, interruptThread, reason) //杀死task
  }

  override def receiveAndReply(context: RpcCallContext): PartialFunction[Any, Unit] = {
    case StopExecutor => //停止executor并响应true
      executor.stop()
      context.reply(true)
  }

  def reviveOffers(): Unit = {
    // local mode doesn't support extra resources like GPUs right now
    val offers = IndexedSeq(new WorkerOffer(localExecutorId, localExecutorHostname, freeCores,
      Some(rpcEnv.address.hostPort)))
    for (task <- scheduler.resourceOffers(offers).flatten) {
      freeCores -= scheduler.CPUS_PER_TASK
      executor.launchTask(executorBackend, task)
    }
  }
}

/**
 * Used when running a local version of Spark where the executor, backend, and master all run in
 * the same JVM. It sits behind a [[TaskSchedulerImpl]] and handles launching tasks on a single
 * Executor (created by the [[LocalSchedulerBackend]]) running locally.
 */
private[spark] class LocalSchedulerBackend( //本地任务调度后台
    conf: SparkConf,
    scheduler: TaskSchedulerImpl,
    val totalCores: Int)
  extends SchedulerBackend with ExecutorBackend with Logging {

  private val appId = "local-" + System.currentTimeMillis
  private var localEndpoint: RpcEndpointRef = null
  private val userClassPath = getUserClasspath(conf)
  private val listenerBus = scheduler.sc.listenerBus //用于浏览器刷新状态
  //rpc调用方，调用上述的rpc的提供方：LocalEndpoint 向它下发指令，并接收反馈
  private val launcherBackend = new LauncherBackend() { 
    override def conf: SparkConf = LocalSchedulerBackend.this.conf
    override def onStopRequest(): Unit = stop(SparkAppHandle.State.KILLED)
  }

  /**
   * Returns a list of URLs representing the user classpath.
   *
   * @param conf Spark configuration.
   */
  def getUserClasspath(conf: SparkConf): Seq[URL] = {
    val userClassPathStr = conf.get(config.EXECUTOR_CLASS_PATH)
    userClassPathStr.map(_.split(File.pathSeparator)).toSeq.flatten.map(new File(_).toURI.toURL)
  }

  launcherBackend.connect()

  override def start(): Unit = {
    val rpcEnv = SparkEnv.get.rpcEnv
    val executorEndpoint = new LocalEndpoint(rpcEnv, userClassPath, scheduler, this, totalCores)
    localEndpoint = rpcEnv.setupEndpoint("LocalSchedulerBackendEndpoint", executorEndpoint)
    listenerBus.post(SparkListenerExecutorAdded(
      System.currentTimeMillis,
      executorEndpoint.localExecutorId,
      new ExecutorInfo(executorEndpoint.localExecutorHostname, totalCores, Map.empty,
        Map.empty)))
    launcherBackend.setAppId(appId)
    launcherBackend.setState(SparkAppHandle.State.RUNNING)
  }

  override def stop(): Unit = {
    stop(SparkAppHandle.State.FINISHED)
  }

  override def reviveOffers(): Unit = {
    localEndpoint.send(ReviveOffers)  //向rpc终端发送命令 ---> 消费task
  }

  override def defaultParallelism(): Int = //默认的并行度，我们可以在sparkcontext中设置
    scheduler.conf.getInt("spark.default.parallelism", totalCores)

  override def killTask(
      taskId: Long, executorId: String, interruptThread: Boolean, reason: String): Unit = {    //向rpc终端发送命令 --->杀死task
    localEndpoint.send(KillTask(taskId, interruptThread, reason))
  }

  override def statusUpdate(taskId: Long, state: TaskState, serializedData: ByteBuffer): Unit = {
     //向rpc终端发送命令 --->更新task状态
    localEndpoint.send(StatusUpdate(taskId, state, serializedData))
  }

  override def applicationId(): String = appId
  //最大并行任务数量= 全部cpu核/单任务占用（默认为1）
  override def maxNumConcurrentTasks(): Int = totalCores / scheduler.CPUS_PER_TASK

  private def stop(finalState: SparkAppHandle.State): Unit = {
    localEndpoint.ask(StopExecutor)  //向rpc终端发送命令 --->杀死excutor并返回true
    try {
      launcherBackend.setState(finalState)
    } finally {
      launcherBackend.close() //关闭rpc调用方
    }
  }

}
```

```scala
// ################ org.apache.spark.scheduler.TaskScheduler #######################
/**
 * Low-level task scheduler interface, currently implemented exclusively by
 * [[org.apache.spark.scheduler.TaskSchedulerImpl]].
 * This interface allows plugging in different task schedulers. Each TaskScheduler schedules tasks
 * for a single SparkContext. These schedulers get sets of tasks submitted to them from the
 * DAGScheduler for each stage, and are responsible for sending the tasks to the cluster, running
 * them, retrying if there are failures, and mitigating stragglers. They return events to the
 * DAGScheduler.
 */

// 任务调度器接口
private[spark] trait TaskScheduler {

  private val appId = "spark-application-" + System.currentTimeMillis

  def rootPool: Pool

  def schedulingMode: SchedulingMode // FAIR, FIFO, NONE三种调度策略

  def start(): Unit

  // Invoked after system has successfully initialized (typically in spark context).
  // Yarn uses this to bootstrap allocation of resources based on preferred locations,
  // wait for slave registrations, etc.
  def postStartHook(): Unit = { }

  // Disconnect from the cluster.
  def stop(): Unit

  // Submit a sequence of tasks to run.
  def submitTasks(taskSet: TaskSet): Unit

  // Kill all the tasks in a stage and fail the stage and all the jobs that depend on the stage.
  // Throw UnsupportedOperationException if the backend doesn't support kill tasks.
  def cancelTasks(stageId: Int, interruptThread: Boolean): Unit

  /**
   * Kills a task attempt.
   * Throw UnsupportedOperationException if the backend doesn't support kill a task.
   *
   * @return Whether the task was successfully killed.
   */
  def killTaskAttempt(taskId: Long, interruptThread: Boolean, reason: String): Boolean

  // Kill all the running task attempts in a stage.
  // Throw UnsupportedOperationException if the backend doesn't support kill tasks.
  def killAllTaskAttempts(stageId: Int, interruptThread: Boolean, reason: String): Unit

  // Notify the corresponding `TaskSetManager`s of the stage, that a partition has already completed
  // and they can skip running tasks for it.
  def notifyPartitionCompletion(stageId: Int, partitionId: Int): Unit

  // Set the DAG scheduler for upcalls. This is guaranteed to be set before submitTasks is called.
  def setDAGScheduler(dagScheduler: DAGScheduler): Unit

  // Get the default level of parallelism to use in the cluster, as a hint for sizing jobs.
  def defaultParallelism(): Int

  /**
   * Update metrics for in-progress tasks and executor metrics, and let the master know that the
   * BlockManager is still alive. Return true if the driver knows about the given block manager.
   * Otherwise, return false, indicating that the block manager should re-register.
   */
  def executorHeartbeatReceived(
      execId: String,
      accumUpdates: Array[(Long, Seq[AccumulatorV2[_, _]])],
      blockManagerId: BlockManagerId,
      executorUpdates: Map[(Int, Int), ExecutorMetrics]): Boolean

  /**
   * Get an application ID associated with the job.
   *
   * @return An application ID
   */
  def applicationId(): String = appId

  /**
   * Process a lost executor
   */
  def executorLost(executorId: String, reason: ExecutorLossReason): Unit

  /**
   * Process a removed worker
   */
  def workerRemoved(workerId: String, host: String, message: String): Unit

  /**
   * Get an application's attempt ID associated with the job.
   *
   * @return An application's Attempt ID
   */
  def applicationAttemptId(): Option[String]

}

```



```java
/*
free参数记录
$ free
              total        used        free      shared  buff/cache   available
Mem:        8169348      263524     6875352         668     1030472     7611064
Swap:             0           0           0

# 具体变化情况可以通过 vmstat监控

# 首先清理缓存
echo 3 > /proc/sys/vm/drop_caches
#向/tmp/file 文件 中写入数据    --写文件
dd if=/dev/urandom of=/tmp/file bs=1M count=500 

# 首先清理缓存
echo 3 > /proc/sys/vm/drop_caches
# 然后运行dd命令向 磁盘分区 /dev/sdb1写入2G数据  --写磁盘
dd if=/dev/urandom of=/dev/sdb1 bs=1M count=2048

# 首先清理缓存
echo 3 > /proc/sys/vm/drop_caches
# 运行dd命令 读取 文件 数据  --读文件
dd if=/tmp/file of=/dev/null


# 首先清理缓存
echo 3 > /proc/sys/vm/drop_caches
# 运行dd 命令 读取磁盘  --读磁盘
dd if=/dev/sda1 of=/dev/null bs=1M count=1024

Buffers 是对原始磁盘块的临时存储，也就是用来缓存磁盘的数据，通常不会特别大（20MB 左右）。这样，内核就可以把分散的写集中起来，统一优化磁盘的写入，比如可以把多次小的写合并成单次大的写等等。

Cached 是从磁盘读取文件的页缓存，也就是用来缓存从文件读取的数据。这样，下次访问这些文件数据时，就可以直接从内存中快速获取，而不需要再次访问缓慢的磁盘。

Buffer 既可以用作“将要写入磁盘数据的缓存”，也可以用作“从磁盘读取数据的缓存”。
Cache 既可以用作“从文件读取数据的页缓存”，也可以用作“写文件的页缓存”。
简单来说，Buffer 是对磁盘数据的缓存，而 Cache 是文件数据的缓存，它们既会用在读请求中，也会用在写请求中。

*/
```

```scala
// ########################## org.apache.spark.SparkEnv #################################

/**
Holds all the runtime environment objects for a running Spark instance (either master or worker),including the serializer, RpcEnv, block manager, map output tracker, etc. It can be accessed by SparkEnv.get (e.g. after creating a SparkContext).

          spark运行时环境 -> 序列化器 - rpc环境 - 块管理器 - map-output-tracker
*/
@DeveloperApi
class SparkEnv (
    val executorId: String,                  // 用于辨别是driver还是executor
    private[spark] val rpcEnv: RpcEnv,       // rpc通信环境
    val serializer: Serializer,              // 序列化器 用于网络传输
    val closureSerializer: Serializer,       // 序列化器 用途暂时未知
    val serializerManager: SerializerManager,// 序列化管理器 决定序列化器种类，是否加密，是否压缩
    val mapOutputTracker: MapOutputTracker,  // 跟踪map阶段（与shuffle有关）完成情况
    val shuffleManager: ShuffleManager,      // 真正执行shuffle操作，涉及读写操作
    val broadcastManager: BroadcastManager,  // 管理广播变量
    val blockManager: BlockManager,          // 文件块管理器
    val securityManager: SecurityManager,    // 安全管理器
    val metricsSystem: MetricsSystem,        // 整合用于监控的指标
    val memoryManager: MemoryManager,        // spark的内存管理  ^-^
    val outputCommitCoordinator: OutputCommitCoordinator,  // 决定哪一个task写入文件到HDFS
    val conf: SparkConf) extends Logging {}  // spark的配置信息，包括默认信息和用户配置信息

```



## 内存管理

### 存储内存管理

```scala
// ################### org.apache.spark.memory.StorageMemoryPool ######################

// storage内存池记账本
private[memory] class StorageMemoryPool(
    lock: Object,
    memoryMode: MemoryMode
  ) extends MemoryPool(lock) with Logging {

  private[this] val poolName: String = memoryMode match {
    case MemoryMode.ON_HEAP => "on-heap storage"
    case MemoryMode.OFF_HEAP => "off-heap storage"
  }

  @GuardedBy("lock")
  private[this] var _memoryUsed: Long = 0L

  override def memoryUsed: Long = lock.synchronized {
    _memoryUsed
  }

  private var _memoryStore: MemoryStore = _
  def memoryStore: MemoryStore = {
    if (_memoryStore == null) {
      throw new IllegalStateException("memory store not initialized yet")
    }
    _memoryStore
  }

  /**
   * Set the [[MemoryStore]] used by this manager to evict cached blocks.
   * This must be set after construction due to initialization ordering constraints.
   */
  final def setMemoryStore(store: MemoryStore): Unit = {
    _memoryStore = store
  }

  // 返回值表示 内存 是否申请成功
  def acquireMemory(blockId: BlockId, numBytes: Long): Boolean = lock.synchronized {
    val numBytesToFree = math.max(0, numBytes - memoryFree)
    acquireMemory(blockId, numBytes, numBytesToFree)
  }


  def acquireMemory(
      blockId: BlockId,
      numBytesToAcquire: Long, // 一共需要多少空间
      numBytesToFree: Long)  // 还需要释放多少空间
    : Boolean = lock.synchronized {
    assert(numBytesToAcquire >= 0)
    assert(numBytesToFree >= 0)
    assert(memoryUsed <= poolSize)
    if (numBytesToFree > 0) {
      // 通过LRU淘汰策略 淘汰部分block，直到释放足够的空间
      memoryStore.evictBlocksToFreeSpace(Some(blockId), numBytesToFree, memoryMode)
    }

    val enoughMemory = numBytesToAcquire <= memoryFree
    if (enoughMemory) { // 再次判断所需要的空间是否可以满足
      _memoryUsed += numBytesToAcquire
    }
    enoughMemory
  }

  def releaseMemory(size: Long): Unit = lock.synchronized {
    if (size > _memoryUsed) {
      logWarning(s"Attempted to release $size bytes of storage " +
        s"memory when we only have ${_memoryUsed} bytes")
      _memoryUsed = 0
    } else {
      _memoryUsed -= size
    }
  }

  def releaseAllMemory(): Unit = lock.synchronized {
    _memoryUsed = 0
  }

  // 返回从storage空间借出的空间大小 
  def freeSpaceToShrinkPool(spaceToFree: Long): Long = lock.synchronized {
    val spaceFreedByReleasingUnusedMemory = math.min(spaceToFree, memoryFree)
    val remainingSpaceToFree = spaceToFree - spaceFreedByReleasingUnusedMemory
if (remainingSpaceToFree > 0) { //如果storage空间不够的话，释放部分block，返回释放后给予的空间大小
      val spaceFreedByEviction =
        memoryStore.evictBlocksToFreeSpace(None, remainingSpaceToFree, memoryMode)
      spaceFreedByReleasingUnusedMemory + spaceFreedByEviction
    } else {
      // storage空间够用的话 直接返回所需要的空间大小
      spaceFreedByReleasingUnusedMemory
    }
  }
}
// 其中最关心的是 storage空间的淘汰策略: memoryStore.evictBlocksToFreeSpace
// ###########org.apache.spark.storage.memory.MemoryStore#evictBlocksToFreeSpace ########
  private[spark] def evictBlocksToFreeSpace(
      blockId: Option[BlockId],
      space: Long,
      memoryMode: MemoryMode): Long = {
    assert(space > 0)
    memoryManager.synchronized {
      var freedMemory = 0L
      val rddToAdd = blockId.flatMap(getRddId)
      val selectedBlocks = new ArrayBuffer[BlockId]
      // 什么条件下一个block可以淘汰呢？ 
      // 1. 当block的memoryMode和指定的一致
      // 2. 当从evictBlocksToFreeSpace传入的blockId不对应于rdd或者 对应的rdd与即将淘汰的blockId             对应的rdd不是同一个rdd时(避免循环淘汰)
      def blockIsEvictable(blockId: BlockId, entry: MemoryEntry[_]): Boolean = {
        entry.memoryMode == memoryMode && (rddToAdd.isEmpty || rddToAdd != getRddId(blockId))
      }
      // This is synchronized to ensure that the set of entries is not changed
      // (because of getValue or getBytes) while traversing the iterator, as that
      // can lead to exceptions.
      entries.synchronized {
        val iterator = entries.entrySet().iterator()
        while (freedMemory < space && iterator.hasNext) {
          val pair = iterator.next()
          val blockId = pair.getKey
          val entry = pair.getValue
          if (blockIsEvictable(blockId, entry)) {
          // 我们不希望淘汰正在被其他任务读取的block 能够成功获取写锁，说明该block没有被读取，可以淘汰
            if (blockInfoManager.lockForWriting(blockId, blocking = false).isDefined) {
              selectedBlocks += blockId
              freedMemory += pair.getValue.size
            }
          }
        }
      }
//#####################################dropBlock#########################################
      def dropBlock[T](blockId: BlockId, entry: MemoryEntry[T]): Unit = {
        val data = entry match {
          case DeserializedMemoryEntry(values, _, _) => Left(values) // 非序列化数据
          case SerializedMemoryEntry(buffer, _, _) => Right(buffer)  // 序列化数据
        }
        // 得到一个新的StorageLevel
        val newEffectiveStorageLevel =
          // *** 真正的实现在：org.apache.spark.storage.BlockManager#dropFromMemory ***
          blockEvictionHandler.dropFromMemory(blockId, () => data)(entry.classTag)
        if (newEffectiveStorageLevel.isValid) {
          // 该block还存在一个副本，则只需要释放写锁就可以
          blockInfoManager.unlock(blockId)
        } else {
          // 该block在内存中已经不存在副本了，在blockInfoManager删除对应的元数据
          blockInfoManager.removeBlock(blockId)
        }
      }
//#######################################################################################
      if (freedMemory >= space) {
        var lastSuccessfulBlock = -1
        try {
          logInfo(s"${selectedBlocks.size} blocks selected for dropping " +
            s"(${Utils.bytesToString(freedMemory)} bytes)")
          (0 until selectedBlocks.size).foreach { idx =>
            val blockId = selectedBlocks(idx)
            val entry = entries.synchronized {
              entries.get(blockId)
            }
            // This should never be null as only one task should be dropping
            // blocks and removing entries. However the check is still here for
            // future safety.
            if (entry != null) {
              dropBlock(blockId, entry)
              afterDropAction(blockId)
            }
            lastSuccessfulBlock = idx
          }
          logInfo(s"After dropping ${selectedBlocks.size} blocks, " +
            s"free memory is ${Utils.bytesToString(maxMemory - blocksMemoryUsed)}")
          freedMemory
        } finally {
// like BlockManager.doPut, we use a finally rather than a catch to avoid having to deal
// with InterruptedException
          if (lastSuccessfulBlock != selectedBlocks.size - 1) {
// the blocks we didn't process successfully are still locked, so we have to unlock them
            (lastSuccessfulBlock + 1 until selectedBlocks.size).foreach { idx =>
              val blockId = selectedBlocks(idx)
              blockInfoManager.unlock(blockId)
            }
          }
        }
      } else {
        // 如果所需空间仍然不能满足，则释放所有的锁资源 不实际淘汰 block
        blockId.foreach { id =>
          logInfo(s"Will not store $id")
        }
        selectedBlocks.foreach { id =>
          blockInfoManager.unlock(id)
        }
        0L // 返回真正释放的空间 0L
      }
    }
  }

// 真正淘汰block块数据的代码位于：org.apache.spark.storage.BlockManager#dropFromMemory 
// ########### org.apache.spark.storage.BlockManager#dropFromMemory #####################
  private[storage] override def dropFromMemory[T: ClassTag](
      blockId: BlockId,
      data: () => Either[Array[T], ChunkedByteBuffer]): StorageLevel = {
    logInfo(s"Dropping block $blockId from memory")
    val info = blockInfoManager.assertBlockIsLockedForWriting(blockId)
    var blockIsUpdated = false
    val level = info.level

    // 如果存储等级包含disk,则持久化
    if (level.useDisk && !diskStore.contains(blockId)) {
      logInfo(s"Writing block $blockId to disk")
      data() match {
        case Left(elements) =>  // Array 持久到磁盘，以对象形式存储的非序列化数据
          diskStore.put(blockId) { channel =>
            val out = Channels.newOutputStream(channel)
            serializerManager.dataSerializeStream(
              blockId,
              out,
              elements.toIterator)(info.classTag.asInstanceOf[ClassTag[T]])
          }
        case Right(bytes) =>  // ChunkedByteBuffer 持久到磁盘，以二进制流形式存储的序列化数据
          diskStore.putBytes(blockId, bytes)
      }
      blockIsUpdated = true
    }

    // Actually drop from memory store
    val droppedMemorySize =
      if (memoryStore.contains(blockId)) memoryStore.getSize(blockId) else 0L
      
//====== val blockIsRemoved = memoryStore.remove(blockId)  关键代码 省略部分 ============== 
|  def remove(blockId: BlockId): Boolean = memoryManager.synchronized {                 |
|   val entry = entries.synchronized {                                                  |
|      entries.remove(blockId) // 1. 从LinkedHashMap中清除数据                            |
|    }                                                                                  |
|    if (entry != null) {                                                               | 
|      entry match {                                                                    |
|  // 2. 当entry是序列化对象时，内部包含ChunkedByteBuffer，需要释放 降低垃圾回收的负担           |
|---------------------------------------------------------------------------------------| 
| In Java 8, the type of DirectBuffer.cleaner() was sun.misc.Cleaner and it was possible|
| to access the method sun.misc.Cleaner.clean() to invoke it. The type changed to       | | jdk.internal.ref.Cleaner in later JDKs, and the .clean() method is not accessible even| | with reflection. However sun.misc.Unsafe added a invokeCleaner() method in JDK 9+ and | | this is still accessible with reflection.                                             |
| // 下面一行代码本质上调用 org.apache.spark.storage.StorageUtils$#bufferCleaner Java本地方法|
|---------------------------------------------------------------------------------------|
|  case SerializedMemoryEntry(buffer, _, _) => buffer.dispose()                         |
|  case _ =>                                                                            |
|      }                                                                                |
//====== val blockIsRemoved = memoryStore.remove(blockId)  关键代码 省略部分 ============== 
    val blockIsRemoved = memoryStore.remove(blockId) 
    if (blockIsRemoved) {
      blockIsUpdated = true
    } else {
      logWarning(s"Block $blockId could not be dropped from memory as it does not exist")
    }

    val status = getCurrentBlockStatus(blockId, info)
    if (info.tellMaster) {
      reportBlockStatus(blockId, status, droppedMemorySize)
    }
    if (blockIsUpdated) {
      addUpdatedBlockStatusToTaskMetrics(blockId, status)
    }
    status.storageLevel
  }
```



### 运行内存管理

```scala
// ################### org.apache.spark.memory.ExecutionMemoryPool ######################
/*
Implements policies and bookkeeping for sharing an adjustable-sized pool of memory between tasks. Tries to ensure that each task gets a reasonable share of memory, instead of some task ramping up to a large amount first and then causing others to spill to disk repeatedly. If there are N tasks, it ensures that each task can acquire at least 1 / 2N of the memory before it has to spill, and at most 1 / N. Because N varies dynamically, we keep track of the set of active tasks and redo the calculations of 1 / 2N and 1 / N in waiting tasks whenever this set changes. This is all done by synchronizing access to mutable state and using wait() and notifyAll() to signal changes to callers. Prior to Spark 1.6,this arbitration of memory across tasks was performed by ShuffleMemoryManager.
*/
// 在spill之前 假设一共N个task,尽最大可能保证每个task至少有(1/2N, 1/N)内存
private[memory] class ExecutionMemoryPool(
    lock: Object,
    memoryMode: MemoryMode
  ) extends MemoryPool(lock) with Logging {

  private[this] val poolName: String = memoryMode match {
    case MemoryMode.ON_HEAP => "on-heap execution"
    case MemoryMode.OFF_HEAP => "off-heap execution"
  }

  /**
   * Map from taskAttemptId -> memory consumption in bytes
   */
  @GuardedBy("lock")
  private val memoryForTask = new mutable.HashMap[Long, Long]()

  override def memoryUsed: Long = lock.synchronized {
    memoryForTask.values.sum
  }

  /**
   * Returns the memory consumption, in bytes, for the given task.
   */
  def getMemoryUsageForTask(taskAttemptId: Long): Long = lock.synchronized {
    memoryForTask.getOrElse(taskAttemptId, 0L)
  }

  // 要么使用的内存大于1/N，立刻返回 | 要么min(总内存/2N,要求的内存）能够得到满足，返回
  private[memory] def acquireMemory(
      numBytes: Long,
      taskAttemptId: Long,
      maybeGrowPool: Long => Unit = (additionalSpaceNeeded: Long) => (),
      computeMaxPoolSize: () => Long = () => poolSize): Long = lock.synchronized {
    assert(numBytes > 0, s"invalid number of bytes requested: $numBytes")
// Add this task to the taskMemory map just so we can keep an accurate count of the number of active tasks, to let other tasks ramp down their memory in calls to `acquireMemory`
    if (!memoryForTask.contains(taskAttemptId)) {
      memoryForTask(taskAttemptId) = 0L
      // This will later cause waiting tasks to wake up and check numTasks again
      lock.notifyAll()
    }

// Keep looping until we're either sure that we don't want to grant this request (because this task would have more than 1 / numActiveTasks of the memory) or we have enough free memory to give it (we always let each task get at least 1 / (2 * numActiveTasks)).
    while (true) {
      val numActiveTasks = memoryForTask.keys.size
      val curMem = memoryForTask(taskAttemptId)

// In every iteration of this loop, we should first try to reclaim any borrowed execution  space from storage. This is necessary because of the potential race condition where new storage blocks may steal the free execution memory that this task was waiting for.
      maybeGrowPool(numBytes - memoryFree) // 通过该方法 尝试借用storage空间，增大executor空间

// Maximum size the pool would have after potentially growing the pool. This is used to compute the upper bound of how much memory each task can occupy. This must take into account potential free memory as well as the amount this pool currently occupies. Otherwise, we may run into SPARK-12155 where, in unified memory management, we did not take into account space that could have been freed by evicting cached blocks.
      val maxPoolSize = computeMaxPoolSize()
      val maxMemoryPerTask = maxPoolSize / numActiveTasks
      val minMemoryPerTask = poolSize / (2 * numActiveTasks)

// How much we can grant this task; keep its share within 0 <= X <= 1 / numActiveTasks
      val maxToGrant = math.min(numBytes, math.max(0, maxMemoryPerTask - curMem))
// Only give it as much memory as is free, which might be none if it reached 1 / numTasks
      val toGrant = math.min(maxToGrant, memoryFree)

// We want to let each task get at least 1 / (2 * numActiveTasks) before blocking;
// if we can't give it this much now, wait for other tasks to free up memory
// (this happens if older tasks allocated lots of memory before N grew)
      if (toGrant < numBytes && curMem + toGrant < minMemoryPerTask) {
        logInfo(s"TID $taskAttemptId waiting for at least 1/2N of $poolName pool to be free")
        lock.wait()
      } else {
        memoryForTask(taskAttemptId) += toGrant
        return toGrant
      }
    }
    0L  // Never reached
  }

  /**
   * Release `numBytes` of memory acquired by the given task.
   */
  def releaseMemory(numBytes: Long, taskAttemptId: Long): Unit = lock.synchronized {
    val curMem = memoryForTask.getOrElse(taskAttemptId, 0L)
    val memoryToFree = if (curMem < numBytes) {
      logWarning(
        s"Internal error: release called on $numBytes bytes but task only has $curMem bytes " +
          s"of memory from the $poolName pool")
      curMem
    } else {
      numBytes
    }
    if (memoryForTask.contains(taskAttemptId)) {
      memoryForTask(taskAttemptId) -= memoryToFree
      if (memoryForTask(taskAttemptId) <= 0) {
        memoryForTask.remove(taskAttemptId)
      }
    }
    lock.notifyAll() // Notify waiters in acquireMemory() that memory has been freed
  }

  /**
   * Release all memory for the given task and mark it as inactive (e.g. when a task ends).
   * @return the number of bytes freed.
   */
  def releaseAllMemoryForTask(taskAttemptId: Long): Long = lock.synchronized {
    val numBytesToFree = getMemoryUsageForTask(taskAttemptId)
    releaseMemory(numBytesToFree, taskAttemptId)
    numBytesToFree
  }

}

```

### 统一内存管理

```scala
// 统一内存管理 包括上面提到的storage内存管理和executor内存管理
// ######################### org.apache.spark.memory.UnifiedMemoryManager ###############
package org.apache.spark.memory

import org.apache.spark.SparkConf
import org.apache.spark.internal.config
import org.apache.spark.internal.config.Tests._
import org.apache.spark.storage.BlockId

// 统一内存管理 采用动态占用机制 会有LRU淘汰机制
private[spark] class UnifiedMemoryManager(
    conf: SparkConf,
    val maxHeapMemory: Long,
    onHeapStorageRegionSize: Long,
    numCores: Int)
  extends MemoryManager(
    conf,
    numCores,
    onHeapStorageRegionSize,
    maxHeapMemory - onHeapStorageRegionSize) {

  private def assertInvariants(): Unit = {
    // 堆内空间  ExecutionMemory + StorageMemory
    assert(onHeapExecutionMemoryPool.poolSize + onHeapStorageMemoryPool.poolSize == maxHeapMemory)
    // 堆外空间： ExecutionMemory + StorageMemory
    assert(
      offHeapExecutionMemoryPool.poolSize + offHeapStorageMemoryPool.poolSize == maxOffHeapMemory)
  }

  assertInvariants()

  override def maxOnHeapStorageMemory: Long = synchronized {
    maxHeapMemory - onHeapExecutionMemoryPool.memoryUsed
  }

  override def maxOffHeapStorageMemory: Long = synchronized {
    maxOffHeapMemory - offHeapExecutionMemoryPool.memoryUsed
  }

// 尝试获取numBytes字节的内存空间
  override private[memory] def acquireExecutionMemory(
      numBytes: Long,
      taskAttemptId: Long,
      memoryMode: MemoryMode): Long = synchronized {
    assertInvariants()
    assert(numBytes >= 0)
    val (executionPool, storagePool, storageRegionSize, maxMemory) = memoryMode match {
      // 根据内存模式选择不同的内存池 堆内 堆外
      case MemoryMode.ON_HEAP => (
        onHeapExecutionMemoryPool,
        onHeapStorageMemoryPool,
        onHeapStorageRegionSize,
        maxHeapMemory)
      case MemoryMode.OFF_HEAP => (
        offHeapExecutionMemoryPool,
        offHeapStorageMemoryPool,
        offHeapStorageMemory,
        maxOffHeapMemory)
    }
    // 当executor空间不足时，可以抢占storage空间的内存
    def maybeGrowExecutionPool(extraMemoryNeeded: Long): Unit = {
      if (extraMemoryNeeded > 0) {
        val memoryReclaimableFromStorage = math.max(
          storagePool.memoryFree,
          storagePool.poolSize - storageRegionSize)
        if (memoryReclaimableFromStorage > 0) {
          // 向storage内存池借用
          val spaceToReclaim = storagePool.freeSpaceToShrinkPool(
            math.min(extraMemoryNeeded, memoryReclaimableFromStorage))
          // storage内存池内存池记账本 减少内存
          storagePool.decrementPoolSize(spaceToReclaim)
          // execution内存池记账本 添加内存
          executionPool.incrementPoolSize(spaceToReclaim)
        }
      }
    }

   
    def computeMaxExecutionPoolSize(): Long = {
      // 返回最大可使用Execution内存 包括storage已经借用的部分和storage空闲的部分
      maxMemory - math.min(storagePool.memoryUsed, storageRegionSize)
    }

    executionPool.acquireMemory(
      numBytes, taskAttemptId, maybeGrowExecutionPool, () => computeMaxExecutionPoolSize)
  }

  override def acquireStorageMemory(
      blockId: BlockId,
      numBytes: Long,
      memoryMode: MemoryMode): Boolean = synchronized {
    assertInvariants()
    assert(numBytes >= 0)
    val (executionPool, storagePool, maxMemory) = memoryMode match {
      case MemoryMode.ON_HEAP => (
        onHeapExecutionMemoryPool,
        onHeapStorageMemoryPool,
        maxOnHeapStorageMemory)
      case MemoryMode.OFF_HEAP => (
        offHeapExecutionMemoryPool,
        offHeapStorageMemoryPool,
        maxOffHeapStorageMemory)
    }
    if (numBytes > maxMemory) {
      // Fail fast if the block simply won't fit
      logInfo(s"Will not store $blockId as the required space ($numBytes bytes) exceeds our " + s"memory limit ($maxMemory bytes)")
      return false
    }
    if (numBytes > storagePool.memoryFree) {
// There is not enough free memory in the storage pool, so try to borrow free memory from the execution pool.
      val memoryBorrowedFromExecution = Math.min(executionPool.memoryFree,
        numBytes - storagePool.memoryFree)
      executionPool.decrementPoolSize(memoryBorrowedFromExecution)
      storagePool.incrementPoolSize(memoryBorrowedFromExecution)
    }
    storagePool.acquireMemory(blockId, numBytes)
  }

  override def acquireUnrollMemory(
      blockId: BlockId,
      numBytes: Long,
      memoryMode: MemoryMode): Boolean = synchronized {
    acquireStorageMemory(blockId, numBytes, memoryMode)
  }
}

object UnifiedMemoryManager {
// the memory used for execution and storage will be (1024 - 300) * 0.6 = 434MB by default. 预留300M 用于系统内部使用
  private val RESERVED_SYSTEM_MEMORY_BYTES = 300 * 1024 * 1024
// 假设最大内存1024M
// ExecutorSize=(1024 - 300) * 0.6*0.5
// StorageSize=(1024 - 300) * 0.6*0.5
// 其他内存（spark内部元数据或者用户定义的对象等）(1024 - 300) * 0.4
  def apply(conf: SparkConf, numCores: Int): UnifiedMemoryManager = {
    val maxMemory = getMaxMemory(conf)
    new UnifiedMemoryManager(
      conf,
      maxHeapMemory = maxMemory,
      onHeapStorageRegionSize =
        (maxMemory * conf.get(config.MEMORY_STORAGE_FRACTION)).toLong,
      numCores = numCores)
  }

  /**
   * Return the total amount of memory shared between execution and storage, in bytes.
   */
  private def getMaxMemory(conf: SparkConf): Long = {
    val systemMemory = conf.get(TEST_MEMORY)
    val reservedMemory = conf.getLong(TEST_RESERVED_MEMORY.key,
      if (conf.contains(IS_TESTING)) 0 else RESERVED_SYSTEM_MEMORY_BYTES)
    val minSystemMemory = (reservedMemory * 1.5).ceil.toLong
    if (systemMemory < minSystemMemory) {
      throw new IllegalArgumentException(s"System memory $systemMemory must " +
        s"be at least $minSystemMemory. Please increase heap size using the --driver-memory " +
        s"option or ${config.DRIVER_MEMORY.key} in Spark configuration.")
    }
    // SPARK-12759 Check executor memory to fail fast if memory is insufficient
    if (conf.contains(config.EXECUTOR_MEMORY)) {
      val executorMemory = conf.getSizeAsBytes(config.EXECUTOR_MEMORY.key)
      if (executorMemory < minSystemMemory) { // JVM堆空间至少应该大于1.5*reservedMemory（默认为450M）
        throw new IllegalArgumentException(s"Executor memory $executorMemory must be at least " +
          s"$minSystemMemory. Please increase executor memory using the " +
          s"--executor-memory option or ${config.EXECUTOR_MEMORY.key} in Spark configuration.")
      }
    }
    val usableMemory = systemMemory - reservedMemory
    val memoryFraction = conf.get(config.MEMORY_FRACTION)
    (usableMemory * memoryFraction).toLong
  }
}

```



## 磁盘管理

```scala
// ######################### org.apache.spark.storage.DiskStore #########################

/**
 * Stores BlockManager blocks on disk.  
 */
private[spark] class DiskStore(
    conf: SparkConf,
    diskManager: DiskBlockManager,
    securityManager: SecurityManager) extends Logging {
  // 开启内存映射的最低阈值(默认2M)，低于这个值，会使得内存映射小文件的开销很大 和页大小有一定关系
  private val minMemoryMapBytes = conf.get(config.STORAGE_MEMORY_MAP_THRESHOLD)
  // 默认值为 Integer.MAX_VALUE - 15
  private val maxMemoryMapBytes = conf.get(config.MEMORY_MAP_LIMIT_FOR_TESTS)
  // 并发map 用于记录blockId占用多大空间
  private val blockSizes = new ConcurrentHashMap[BlockId, Long]()

  def getSize(blockId: BlockId): Long = blockSizes.get(blockId)

  /**
   * 调用传入的writeFunc回调函数，真正将block写回磁盘
   */
  def put(blockId: BlockId)(writeFunc: WritableByteChannel => Unit): Unit = {
    if (contains(blockId)) {
      throw new IllegalStateException(s"Block $blockId is already present in the disk store")
    }
    logDebug(s"Attempting to put block $blockId")
    val startTimeNs = System.nanoTime()
    val file = diskManager.getFile(blockId)  // 获取目录文件描述符，没有则会创建
    // 1. 先基于file打开一个FileOutputStream流 
    // 2.打开文件流中的channel   ** 可以支持并发读写 线程安全 **
    // 3.如果需要加密则再次包装一下
    // 4. CountingWritableChannel(#) 只是增加了一个计数功能
    // 具体逻辑见 org.apache.spark.storage.DiskStore#openForWrite
    // 和 org.apache.spark.storage.CountingWritableChannel
    val out = new CountingWritableChannel(openForWrite(file)) 
    var threwException: Boolean = true
    try {
      writeFunc(out) //这是关键代码 根据传入的方法将block写入磁盘 
      blockSizes.put(blockId, out.getCount) // 并在blockSizes记录该blockId占用的磁盘空间大小
      threwException = false
    } finally {
      try {
        out.close()
      } catch {
        case ioe: IOException =>
          if (!threwException) {
            threwException = true
            throw ioe
          }
      } finally {
         if (threwException) {
          remove(blockId)
        }
      }
    }
    logDebug(s"Block ${file.getName} stored as ${Utils.bytesToString(file.length())} file" +
      s" on disk in ${TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - startTimeNs)} ms")
  }

  def putBytes(blockId: BlockId, bytes: ChunkedByteBuffer): Unit = {
    put(blockId) { channel =>
      // 本质上是利用ChunkedByteBuffer类向上文提到的channel写入数据
      // 所以写入磁盘的关注点在于：
      // ** java.io.FileOutputStream#getChannel **
      // ** org.apache.spark.util.io.ChunkedByteBuffer#writeFully **
      bytes.writeFully(channel) 
    }
  }

  def getBytes(blockId: BlockId): BlockData = {
    getBytes(diskManager.getFile(blockId.name), getSize(blockId))
  }

  def getBytes(f: File, blockSize: Long): BlockData = securityManager.getIOEncryptionKey() match {
    case Some(key) =>
// Encrypted blocks cannot be memory mapped; return a special object that does decryption and provides InputStream / FileRegion implementations for reading the data.
      new EncryptedBlockData(f, blockSize, conf, key)

    case _ =>
      new DiskBlockData(minMemoryMapBytes, maxMemoryMapBytes, f, blockSize)
  }

  def remove(blockId: BlockId): Boolean = { // 移除相应的blockId
    blockSizes.remove(blockId)
    val file = diskManager.getFile(blockId.name)
    if (file.exists()) {
      val ret = file.delete()
      if (!ret) {
        logWarning(s"Error deleting ${file.getPath()}")
      }
      ret
    } else {
      false
    }
  }
  // 文件移动或者单纯的改名
  def moveFileToBlock(sourceFile: File, blockSize: Long, targetBlockId: BlockId): Unit = {
    blockSizes.put(targetBlockId, blockSize)
    val targetFile = diskManager.getFile(targetBlockId.name)
    FileUtils.moveFile(sourceFile, targetFile)
  }
  // blockId是全局唯一的，可以根据该值计算 hash
  // 内部维护了Array[Array[file]]数组 ，可以根据二级索引取得对应的file
  // 1. dirId = hash % localDirs.length
  // 2. subDirId = (hash / localDirs.length) % subDirsPerLocalDir
  // 3. old = subDirs(dirId)(subDirId) 如果该值不存在则创建该目录：
        - File new = File(localDirs(dirId), "%02x".format(subDirId))
  // 4. file.exists()实际询问的是 File(new,blockId.name)是否存在
  // 具体参见 org.apache.spark.storage.DiskBlockManager#getFile
  def contains(blockId: BlockId): Boolean = { 
    val file = diskManager.getFile(blockId.name)
    file.exists()
  }

  private def openForWrite(file: File): WritableByteChannel = {
    // 先得到fileOutputstream流
    val out = new FileOutputStream(file)
    // 再获取其中的双向通道
      .getChannel()
    try {
      // 是否需要加密
      securityManager.getIOEncryptionKey().map { key =>
        CryptoStreamUtils.createWritableChannel(out, conf, key)
      }.getOrElse(out)
    } catch {
      case e: Exception =>
        Closeables.close(out, true)
        file.delete()
        throw e
    }
  }

}

// ################################ DiskBlockData #######################################
// 磁盘block数据的抽象
private class DiskBlockData(
    minMemoryMapBytes: Long, // 触发内存映射 的 最低阈值 默认为 2M
    maxMemoryMapBytes: Long, // 内存映射最大上限 Integer.MAX_VALUE - 15
    file: File,              // 对应的文件描述符
    blockSize: Long)         // 块大小
extends BlockData {

  override def toInputStream(): InputStream = new FileInputStream(file)

  /**
  * Returns a Netty-friendly wrapper for the block's data.
  * Please see `ManagedBuffer.convertToNetty()` for more details.
  */
  override def toNetty(): AnyRef = new DefaultFileRegion(file, 0, size)

  override def toChunkedByteBuffer(allocator: (Int) => ByteBuffer): ChunkedByteBuffer = {
    Utils.tryWithResource(open()) { channel =>
      var remaining = blockSize
      val chunks = new ListBuffer[ByteBuffer]()
      while (remaining > 0) {
        val chunkSize = math.min(remaining, maxMemoryMapBytes)
        val chunk = allocator(chunkSize.toInt) // 分配一片内存空间，供ByteBuffer使用
        remaining -= chunkSize
        JavaUtils.readFully(channel, chunk)   // 从通道中读取数据填充到 chunk(ByteBuffer)中
        chunk.flip()
        chunks += chunk                       // 将chunk(ByteBuffer)加入到chunks
      }
new ChunkedByteBuffer(chunks.toArray)   // 返回的ChunkedByteBuffer实际上是 Array[ByteBuffer]
    }
  }

  override def toByteBuffer(): ByteBuffer = {
    require(blockSize < maxMemoryMapBytes,
      s"can't create a byte buffer of size $blockSize" +
      s" since it exceeds ${Utils.bytesToString(maxMemoryMapBytes)}.")
    Utils.tryWithResource(open()) { channel =>
      if (blockSize < minMemoryMapBytes) {
        // 小文件 直接读取
        val buf = ByteBuffer.allocate(blockSize.toInt)
        JavaUtils.readFully(channel, buf)
        buf.flip()  // limit = position ; position = 0; mark = -1;
        buf
      } else {
        // 大文件(>2M) 通过内存映射 只读
        channel.map(MapMode.READ_ONLY, 0, file.length)
      }
    }
  }

  override def size: Long = blockSize

  override def dispose(): Unit = {}

  private def open() = new FileInputStream(file).getChannel  // 得到file对应的通道
}
// ######################################################################################
//                                        加密
// ################################ EncryptedBlockData ##################################
private[spark] class EncryptedBlockData(
    file: File,
    blockSize: Long,
    conf: SparkConf,
    key: Array[Byte]) extends BlockData {

  override def toInputStream(): InputStream = Channels.newInputStream(open())

  override def toNetty(): Object = new ReadableChannelFileRegion(open(), blockSize)

  override def toChunkedByteBuffer(allocator: Int => ByteBuffer): ChunkedByteBuffer = {
    val source = open()
    try {
      var remaining = blockSize
      val chunks = new ListBuffer[ByteBuffer]()
      while (remaining > 0) {
        val chunkSize = math.min(remaining, ByteArrayMethods.MAX_ROUNDED_ARRAY_LENGTH)
        val chunk = allocator(chunkSize.toInt) // 分配一片内存空间，供ByteBuffer使用
        remaining -= chunkSize
        JavaUtils.readFully(source, chunk)  // 从通道中读取数据填充到 chunk(ByteBuffer)中
        chunk.flip()
        chunks += chunk // 将chunk(ByteBuffer)加入到chunks
      }

  new ChunkedByteBuffer(chunks.toArray) // 返回的ChunkedByteBuffer实际上是 Array[ByteBuffer]
    } finally {
      source.close()
    }
  }

  override def toByteBuffer(): ByteBuffer = {
// This is used by the block transfer service to replicate blocks. The upload code reads  all bytes into memory to send the block to the remote executor, so it's ok to do this as long as the block fits in a Java array.
    assert(blockSize <= ByteArrayMethods.MAX_ROUNDED_ARRAY_LENGTH,
      "Block is too large to be wrapped in a byte buffer.")
    val dst = ByteBuffer.allocate(blockSize.toInt)
    val in = open()
    try {
      JavaUtils.readFully(in, dst)
      dst.flip()
      dst
    } finally {
      Closeables.close(in, true)
    }
  }

  override def size: Long = blockSize

  override def dispose(): Unit = { }

  private def open(): ReadableByteChannel = {
    val channel = new FileInputStream(file).getChannel()
    try {
      CryptoStreamUtils.createReadableChannel(channel, conf, key) // 包装流 提供加密方法
    } catch {
      case e: Exception =>
        Closeables.close(channel, true)
        throw e
    }
  }
}
// ######################################################################################
//     提供一些转换方法： #nioByteBuffer() #convertToNetty() #createInputStream()
// ######################### EncryptedManagedBuffer #####################################

private[spark] class EncryptedManagedBuffer(
    val blockData: EncryptedBlockData) extends ManagedBuffer {

  // This is the size of the decrypted data
  override def size(): Long = blockData.size

  override def nioByteBuffer(): ByteBuffer = blockData.toByteBuffer()

  override def convertToNetty(): AnyRef = blockData.toNetty()

  override def createInputStream(): InputStream = blockData.toInputStream()

  override def retain(): ManagedBuffer = this

  override def release(): ManagedBuffer = this
}
// ######################################################################################
//         借助一个64kib的缓冲buffer ByteBuffer 将文件从一个通道转移到另一个通道
// ######################### ReadableChannelFileRegion ##################################
private class ReadableChannelFileRegion(source: ReadableByteChannel, blockSize: Long)
  extends AbstractFileRegion {

  private var _transferred = 0L

  private val buffer = ByteBuffer.allocateDirect(64 * 1024)  // 64 kib ByteBuffer
  buffer.flip()

  override def count(): Long = blockSize

  override def position(): Long = 0

  override def transferred(): Long = _transferred

  override def transferTo(target: WritableByteChannel, pos: Long): Long = {
    assert(pos == transferred(), "Invalid position.")

    var written = 0L
    var lastWrite = -1L
    while (lastWrite != 0) {
      if (!buffer.hasRemaining()) { // buffer大小 64kib
        buffer.clear()
        source.read(buffer)  // 从源 channel读取到缓冲区
        buffer.flip()
      }
      if (buffer.hasRemaining()) {
        lastWrite = target.write(buffer)  //  // 将缓冲区数据写到 目的 channel
        written += lastWrite
      } else {
        lastWrite = 0
      }
    }

    _transferred += written
    written
  }

  override def deallocate(): Unit = source.close()
}
// ######################################################################################
//                       包装类 包装了一下 channel 增加计数的功能
// ######################### CountingWritableChannel ####################################
private class CountingWritableChannel(sink: WritableByteChannel) extends WritableByteChannel {

  private var count = 0L

  def getCount: Long = count

  override def write(src: ByteBuffer): Int = {
    val written = sink.write(src)
    if (written > 0) {
      count += written
    }
    written
  }

  override def isOpen(): Boolean = sink.isOpen()

  override def close(): Unit = sink.close()

}

```

```scala
// ############################# ChunkedByteBuffer ######################################
/**
 * Read-only byte buffer which is physically stored as multiple chunks rather than a single contiguous array. 
 @param chunks an array of [[ByteBuffer]]s. Each buffer in this array must have position == 0. Ownership of these buffers is transferred to the ChunkedByteBuffer, so if these buffers may also be used elsewhere then the caller is responsible for copying them as needed.
 */

// 只读buffer 初始化时 position =0
private[spark] class ChunkedByteBuffer(var chunks: Array[ByteBuffer]) {
  require(chunks != null, "chunks must not be null")
  require(chunks.forall(_.position() == 0), "chunks' positions must be 0")

  // 默认值为 64M 用户设置的值也不能超过 Integer.MAX_VALUE - 15 bytes(约等于2G)
  private val bufferWriteChunkSize =
    Option(SparkEnv.get).map(_.conf.get(config.BUFFER_WRITE_CHUNK_SIZE))
      .getOrElse(config.BUFFER_WRITE_CHUNK_SIZE.defaultValue.get).toInt

  private[this] var disposed: Boolean = false

  /**
   * This size of this buffer, in bytes.
   */
  val size: Long = chunks.map(_.limit().asInstanceOf[Long]).sum

  def this(byteBuffer: ByteBuffer) = {
    this(Array(byteBuffer))
  }

  /**
   * Write this buffer to a channel.
   */
  def writeFully(channel: WritableByteChannel): Unit = {
    for (bytes <- getChunks()) {
      val originalLimit = bytes.limit()
      while (bytes.hasRemaining) {
/* --------------------------------------------------------------------------------------
If `bytes` is an on-heap ByteBuffer, the Java NIO API will copy it to a temporary direct ByteBuffer when writing it out. This temporary direct ByteBuffer is cached per thread. Its size has no limit and can keep growing if it sees a larger input ByteBuffer. This may cause significant native memory leak, if a large direct ByteBuffer is allocated and cached, as it's never released until thread exits. Here we write the `bytes` with fixed-size slices to limit the size of the cached direct ByteBuffer. Please refer to http://www.evanjones.ca/java-bytebuffer-leak.html for more details.

简单来说ByteBuffer实现分两种，一种是 堆内实现(HeapByteBuffer)， 一种是堆外实现(DirectByteBuffer)
其中HeapByteBuffer因为会涉及垃圾回收，不安全，所以它的实现会在堆外空间创建一个临时buffer(temporary direct ByteBuffer),写入操作是写入到堆外的临时buffer,读取也是从临时buffer中读取。临时buffer它会缓存每次写入数据的最大值，并且是基于线程缓存的，每个线程都会缓存一个。直到线程释放才会释放这些堆外内存。所以很多时候就会出现内存泄漏的现象 

## 此处---> 通过限制每次写入字节大小 来限制 堆外空间的内存缓存大小

## 当然我们也可以直接使用DirectByteBuffer，就不会有这个问题了
--------------------------------------------------------------------------------------*/      
        val ioSize = Math.min(bytes.remaining(), bufferWriteChunkSize)
        bytes.limit(bytes.position() + ioSize)
        channel.write(bytes) // 一次只传输固定大小的数据 ，具体原因见上面的解释
        bytes.limit(originalLimit)
      }
    }
  }

  /**
   * Wrap this in a custom "FileRegion" which allows us to transfer over 2 GB.
   */
  def toNetty: ChunkedByteBufferFileRegion = {
    new ChunkedByteBufferFileRegion(this, bufferWriteChunkSize)  // 为了支持传输的文件大于2G
  }

  /**
   * Copy this buffer into a new byte array.
   * @throws UnsupportedOperationException if this buffer's size exceeds the maximum array size.
   */
  def toArray: Array[Byte] = {
    if (size >= ByteArrayMethods.MAX_ROUNDED_ARRAY_LENGTH) {
      throw new UnsupportedOperationException(
        s"cannot call toArray because buffer size ($size bytes) exceeds maximum array size")
    }
    val byteChannel = new ByteArrayWritableChannel(size.toInt)
    writeFully(byteChannel)
    byteChannel.close()
    byteChannel.getData
  }

  /**
   * Convert this buffer to a ByteBuffer. If this buffer is backed by a single chunk, its underlying data will not be copied. Instead, it will be duplicated. If this buffer is backed by multiple chunks, the data underlying this buffer will be copied into a new byte buffer. As a result, it is suggested to use this method only if the caller does not need to manage the memory underlying this buffer.
   * @throws UnsupportedOperationException if this buffer's size exceeds the max               ByteBuffer size.
   */
  def toByteBuffer: ByteBuffer = {
    if (chunks.length == 1) {
      chunks.head.duplicate()
    } else {
      ByteBuffer.wrap(toArray)
    }
  }

  /**
   * Creates an input stream to read data from this ChunkedByteBuffer.
   *
   * @param dispose if true, [[dispose()]] will be called at the end of the stream
   *                in order to close any memory-mapped files which back this buffer.
   */
  def toInputStream(dispose: Boolean = false): InputStream = {
    new ChunkedByteBufferInputStream(this, dispose)
  }

  /**
   * Get duplicates of the ByteBuffers backing this ChunkedByteBuffer.
   * 得到ByteBuffers的副本，每个副本和原来的position limit是互相独立的
   * 该操作不会改变其原有属性 只读->只读 direct->direct
   */
  def getChunks(): Array[ByteBuffer] = {
    chunks.map(_.duplicate())
  }

  /**
   * Make a copy of this ChunkedByteBuffer, copying all of the backing data into new          buffers. The new buffer will share no resources with the original buffer.
   * @param allocator a method for allocating byte buffers
   */
  def copy(allocator: Int => ByteBuffer): ChunkedByteBuffer = {
    val copiedChunks = getChunks().map { chunk =>
      val newChunk = allocator(chunk.limit())
      newChunk.put(chunk)
      newChunk.flip()
      newChunk
    }
    new ChunkedByteBuffer(copiedChunks)
  }

  /**
   * Attempt to clean up any ByteBuffer in this ChunkedByteBuffer which is direct or memory-mapped. See [[StorageUtils.dispose]] for more information.
   */
  def dispose(): Unit = {
    if (!disposed) {
      chunks.foreach(StorageUtils.dispose) // 会调用java Unsafe方法 进行对象回收 具体见上
      disposed = true
    }
  }

}

private[spark] object ChunkedByteBuffer {

  def fromManagedBuffer(data: ManagedBuffer): ChunkedByteBuffer = {
    data match {
      case f: FileSegmentManagedBuffer =>
        fromFile(f.getFile, f.getOffset, f.getLength)
      case e: EncryptedManagedBuffer =>
        e.blockData.toChunkedByteBuffer(ByteBuffer.allocate _)
      case other =>
        new ChunkedByteBuffer(other.nioByteBuffer())
    }
  }

  def fromFile(file: File): ChunkedByteBuffer = {
    fromFile(file, 0, file.length())
  }

  private def fromFile(
      file: File,
      offset: Long,
      length: Long): ChunkedByteBuffer = {
    // We do *not* memory map the file, because we may end up putting this into the memory store, and spark currently is not expecting memory-mapped buffers in the memory store, it conflicts with other parts that manage the lifecyle of buffers and dispose them.  See SPARK-25422.
    val is = new FileInputStream(file)
    ByteStreams.skipFully(is, offset)
    val in = new LimitedInputStream(is, length)
    val chunkSize = math.min(ByteArrayMethods.MAX_ROUNDED_ARRAY_LENGTH, length).toInt
    val out = new ChunkedByteBufferOutputStream(chunkSize, ByteBuffer.allocate _)
    Utils.tryWithSafeFinally {
      IOUtils.copy(in, out)
    } {
      in.close()
      out.close()
    }
    out.toChunkedByteBuffer
  }
}

/**
 * Reads data from a ChunkedByteBuffer.
 * @param dispose if true, `ChunkedByteBuffer.dispose()` will be called at the end of the stream in order to close any memory-mapped files which back the buffer.
 */
private[spark] class ChunkedByteBufferInputStream(
    var chunkedByteBuffer: ChunkedByteBuffer,
    dispose: Boolean)
  extends InputStream {

  // Filter out empty chunks since `read()` assumes all chunks are non-empty.
  private[this] var chunks = chunkedByteBuffer.getChunks().filter(_.hasRemaining).iterator
  private[this] var currentChunk: ByteBuffer = {
    if (chunks.hasNext) {
      chunks.next()
    } else {
      null
    }
  }

  override def read(): Int = {
    if (currentChunk != null && !currentChunk.hasRemaining && chunks.hasNext) {
      currentChunk = chunks.next()
    }
    if (currentChunk != null && currentChunk.hasRemaining) {
      UnsignedBytes.toInt(currentChunk.get())
    } else {
      close()
      -1
    }
  }

  override def read(dest: Array[Byte], offset: Int, length: Int): Int = {
    if (currentChunk != null && !currentChunk.hasRemaining && chunks.hasNext) {
      currentChunk = chunks.next()
    }
    if (currentChunk != null && currentChunk.hasRemaining) {
      val amountToGet = math.min(currentChunk.remaining(), length)
      currentChunk.get(dest, offset, amountToGet)
      amountToGet
    } else {
      close()
      -1
    }
  }

  override def skip(bytes: Long): Long = { // 跳过指定字节
    if (currentChunk != null) {
      val amountToSkip = math.min(bytes, currentChunk.remaining).toInt
      currentChunk.position(currentChunk.position() + amountToSkip)
      if (currentChunk.remaining() == 0) {
        if (chunks.hasNext) {
          currentChunk = chunks.next()
        } else {
          close()
        }
      }
      amountToSkip
    } else {
      0L
    }
  }

  override def close(): Unit = {
    if (chunkedByteBuffer != null && dispose) {
      // 调用java Unsafe方法进行清理工作 具体见 org.apache.spark.storage.StorageUtils#dispose
      chunkedByteBuffer.dispose() 
    }
    chunkedByteBuffer = null
    chunks = null
    currentChunk = null
  }
}
```























## 广播变量



```scala
//######################org.apache.spark.broadcast.BroadcastManager######################
/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.apache.spark.broadcast

import java.util.Collections
import java.util.concurrent.atomic.AtomicLong

import scala.reflect.ClassTag

import org.apache.commons.collections.map.{AbstractReferenceMap, ReferenceMap}

import org.apache.spark.{SecurityManager, SparkConf}
import org.apache.spark.api.python.PythonBroadcast
import org.apache.spark.internal.Logging

private[spark] class BroadcastManager(
    val isDriver: Boolean,
    conf: SparkConf,
    securityManager: SecurityManager)
  extends Logging {

  private var initialized = false
  // 初始化的时候会赋值为 TorrentBroadcastFactory（本文中省略了部分次要代码）
  private var broadcastFactory: BroadcastFactory = null

  // 原子自增变量，用于唯一确定某一个广播变量
  private val nextBroadcastId = new AtomicLong(0)
  // 缓存广播变量 注意这个同步的map的value为弱引用，也就是当内存不足时触发垃圾回收，存储的引用对象会消亡
  private[broadcast] val cachedValues =
    Collections.synchronizedMap(
      new ReferenceMap(AbstractReferenceMap.HARD, AbstractReferenceMap.WEAK)
        .asInstanceOf[java.util.Map[Any, Any]]
    )
  // 创建一个广播变量
  def newBroadcast[T: ClassTag](value_ : T, isLocal: Boolean): Broadcast[T] = {
    val bid = nextBroadcastId.getAndIncrement()
    value_ match {
      case pb: PythonBroadcast =>
        // SPARK-28486: attach this new broadcast variable's id to the PythonBroadcast,
        // so that underlying data file of PythonBroadcast could be mapped to the
        // BroadcastBlockId according to this id. Please see the specific usage of the
        // id in PythonBroadcast.readObject().
        pb.setBroadcastId(bid)

      case _ => // do nothing
    }
    broadcastFactory.newBroadcast[T](value_, isLocal, bid)
  }
   
  //取消一个广播变量
  def unbroadcast(id: Long, removeFromDriver: Boolean, blocking: Boolean): Unit = {
    broadcastFactory.unbroadcast(id, removeFromDriver, blocking)
  }
}
// 需要重点关心创建一个广播变量 和 取消一个广播变量 会涉及内存存储和节点通信
```

```scala
//######################org.apache.spark.broadcast.TorrentBroadcast######################
/**
 * A BitTorrent-like implementation of [[org.apache.spark.broadcast.Broadcast]].
 *
 * The mechanism is as follows:
The driver divides the serialized object into small chunks and stores those chunks in the BlockManager of the driver.On each executor, the executor first attempts to fetch the object from its BlockManager. If it does not exist, it then uses remote fetches to fetch the small chunks from the driver and/or other executors if available. Once it gets the chunks, it puts the chunks in its own BlockManager, ready for other executors to fetch from.This prevents the driver from being the bottleneck in sending out multiple copies of the broadcast data (one per executor).When initialized, TorrentBroadcast objects read SparkEnv.get.conf.
 *
 * @param obj object to broadcast
 * @param id A unique identifier for the broadcast variable.
 */
private[spark] class TorrentBroadcast[T: ClassTag](obj: T, id: Long)
  extends Broadcast[T](id) with Logging with Serializable {

  /**
   * Value of the broadcast object on executors. This is reconstructed by [[readBroadcastBlock]], which builds this value by reading blocks from the driver and/or other executors. On the driver, if the value is required, it is read lazily from the block manager. We hold a soft reference so that it can be garbage collected if required, as we can always reconstruct in the future.
   */
  // 软引用 
  @transient private var _value: SoftReference[T] = _

  /** The compression codec to use, or None if compression is disabled */
  @transient private var compressionCodec: Option[CompressionCodec] = _
  // 默认块大小为 4 M
  @transient private var blockSize: Int = _

  private def setConf(conf: SparkConf): Unit = {
    compressionCodec = if (conf.get(config.BROADCAST_COMPRESS)) {
      Some(CompressionCodec.createCodec(conf))
    } else {
      None
    }
    // use getSizeAsKb (not bytes) to maintain compatibility if no units are provided
    blockSize = conf.get(config.BROADCAST_BLOCKSIZE).toInt * 1024
    checksumEnabled = conf.get(config.BROADCAST_CHECKSUM)
  }
  setConf(SparkEnv.get.conf)

  private val broadcastId = BroadcastBlockId(id)

  /** Total number of blocks this broadcast variable contains. */
  private val numBlocks: Int = writeBlocks(obj)

  /** Whether to generate checksum for blocks or not. */
  private var checksumEnabled: Boolean = false
  /** The checksum for all the blocks. */
  private var checksums: Array[Int] = _

  override protected def getValue() = synchronized {
    val memoized: T = if (_value == null) null.asInstanceOf[T] else _value.get
    if (memoized != null) {
      memoized
    } else {
      // 当得到的值为null时 说明其被垃圾回收了，需要重新获取   ** readBroadcastBlock() **
      val newlyRead = readBroadcastBlock()
      _value = new SoftReference[T](newlyRead)
      newlyRead
    }
  }

  private def calcChecksum(block: ByteBuffer): Int = {
    val adler = new Adler32()
    if (block.hasArray) {
      adler.update(block.array, block.arrayOffset + block.position(), block.limit()
        - block.position())
    } else {
      val bytes = new Array[Byte](block.remaining())
      block.duplicate.get(bytes)
      adler.update(bytes)
    }
    adler.getValue.toInt
  }

  // 将需要存储的对象划分为block进行存储,该函数返回划分的block数量
  private def writeBlocks(value: T): Int = {
    import StorageLevel._
    // driver所在的机器会保存一份广播变量
// * blockManager.putSingle(broadcastId, value, MEMORY_AND_DISK, tellMaster = false) *
    val blockManager = SparkEnv.get.blockManager
      // 会根据设置的存储等级、是否序列化来决定 内存存储还是磁盘存储
    if (!blockManager.putSingle(broadcastId, value, MEMORY_AND_DISK, tellMaster = false)) {
      throw new SparkException(s"Failed to store $broadcastId in BlockManager")
    }
    try {
      val blocks =
        TorrentBroadcast.blockifyObject(value, blockSize, SparkEnv.get.serializer, compressionCodec)
      if (checksumEnabled) {
        checksums = new Array[Int](blocks.length)
      }
      blocks.zipWithIndex.foreach { case (block, i) =>
        if (checksumEnabled) {
          checksums(i) = calcChecksum(block)
        }
        val pieceId = BroadcastBlockId(id, "piece" + i)
        val bytes = new ChunkedByteBuffer(block.duplicate())
        if (!blockManager.putBytes(pieceId, bytes, MEMORY_AND_DISK_SER, tellMaster = true)) {
          throw new SparkException(s"Failed to store $pieceId of $broadcastId " +
            s"in local BlockManager")
        }
      }
      blocks.length
    } catch {
      case t: Throwable =>
        logError(s"Store broadcast $broadcastId fail, remove all pieces of the broadcast")
        blockManager.removeBroadcast(id, tellMaster = true)
        throw t
    }
  }

  /** Fetch torrent blocks from the driver and/or other executors. */
  private def readBlocks(): Array[BlockData] = {
    // Fetch chunks of data. Note that all these chunks are stored in the BlockManager and reported
    // to the driver, so other executors can pull these chunks from this executor as well.
    val blocks = new Array[BlockData](numBlocks)
    val bm = SparkEnv.get.blockManager

    for (pid <- Random.shuffle(Seq.range(0, numBlocks))) {
      val pieceId = BroadcastBlockId(id, "piece" + pid)
      logDebug(s"Reading piece $pieceId of $broadcastId")
      // First try getLocalBytes because there is a chance that previous attempts to fetch the
      // broadcast blocks have already fetched some of the blocks. In that case, some blocks
      // would be available locally (on this executor).
      bm.getLocalBytes(pieceId) match {
        case Some(block) =>
          blocks(pid) = block
          releaseBlockManagerLock(pieceId)
        case None =>
          bm.getRemoteBytes(pieceId) match {
            case Some(b) =>
              if (checksumEnabled) {
                val sum = calcChecksum(b.chunks(0))
                if (sum != checksums(pid)) {
                  throw new SparkException(s"corrupt remote block $pieceId of $broadcastId:" +
                    s" $sum != ${checksums(pid)}")
                }
              }
              // We found the block from remote executors/driver's BlockManager, so put the block
              // in this executor's BlockManager.
              if (!bm.putBytes(pieceId, b, StorageLevel.MEMORY_AND_DISK_SER, tellMaster = true)) {
                throw new SparkException(
                  s"Failed to store $pieceId of $broadcastId in local BlockManager")
              }
              blocks(pid) = new ByteBufferBlockData(b, true)
            case None =>
              throw new SparkException(s"Failed to get $pieceId of $broadcastId")
          }
      }
    }
    blocks
  }

  /**
   * Remove all persisted state associated with this Torrent broadcast on the executors.
   */
  override protected def doUnpersist(blocking: Boolean): Unit = {
    TorrentBroadcast.unpersist(id, removeFromDriver = false, blocking)
  }

  /**
   * Remove all persisted state associated with this Torrent broadcast on the executors
   * and driver.
   */
  override protected def doDestroy(blocking: Boolean): Unit = {
    TorrentBroadcast.unpersist(id, removeFromDriver = true, blocking)
  }

  /** Used by the JVM when serializing this object. */
  private def writeObject(out: ObjectOutputStream): Unit = Utils.tryOrIOException {
    assertValid()
    out.defaultWriteObject()
  }

  private def readBroadcastBlock(): T = Utils.tryOrIOException {
    TorrentBroadcast.torrentBroadcastLock.withLock(broadcastId) {
      // As we only lock based on `broadcastId`, whenever using `broadcastCache`, we should only
      // touch `broadcastId`.
      val broadcastCache = SparkEnv.get.broadcastManager.cachedValues

      Option(broadcastCache.get(broadcastId)).map(_.asInstanceOf[T]).getOrElse {
        setConf(SparkEnv.get.conf)
        val blockManager = SparkEnv.get.blockManager
        blockManager.getLocalValues(broadcastId) match {
          case Some(blockResult) =>
            if (blockResult.data.hasNext) {
              val x = blockResult.data.next().asInstanceOf[T]
              releaseBlockManagerLock(broadcastId)

              if (x != null) {
                broadcastCache.put(broadcastId, x)
              }

              x
            } else {
              throw new SparkException(s"Failed to get locally stored broadcast data: $broadcastId")
            }
          case None =>
            val estimatedTotalSize = Utils.bytesToString(numBlocks * blockSize)
            logInfo(s"Started reading broadcast variable $id with $numBlocks pieces " +
              s"(estimated total size $estimatedTotalSize)")
            val startTimeNs = System.nanoTime()
            val blocks = readBlocks()
            logInfo(s"Reading broadcast variable $id took ${Utils.getUsedTimeNs(startTimeNs)}")

            try {
              val obj = TorrentBroadcast.unBlockifyObject[T](
                blocks.map(_.toInputStream()), SparkEnv.get.serializer, compressionCodec)
              // Store the merged copy in BlockManager so other tasks on this executor don't
              // need to re-fetch it.
              val storageLevel = StorageLevel.MEMORY_AND_DISK
              if (!blockManager.putSingle(broadcastId, obj, storageLevel, tellMaster = false)) {
                throw new SparkException(s"Failed to store $broadcastId in BlockManager")
              }

              if (obj != null) {
                broadcastCache.put(broadcastId, obj)
              }

              obj
            } finally {
              blocks.foreach(_.dispose())
            }
        }
      }
    }
  }

  /**
   * If running in a task, register the given block's locks for release upon task completion.
   * Otherwise, if not running in a task then immediately release the lock.
   */
  private def releaseBlockManagerLock(blockId: BlockId): Unit = {
    val blockManager = SparkEnv.get.blockManager
    Option(TaskContext.get()) match {
      case Some(taskContext) =>
        taskContext.addTaskCompletionListener[Unit](_ => blockManager.releaseLock(blockId))
      case None =>
        // This should only happen on the driver, where broadcast variables may be accessed
        // outside of running tasks (e.g. when computing rdd.partitions()). In order to allow
        // broadcast variables to be garbage collected we need to free the reference here
        // which is slightly unsafe but is technically okay because broadcast variables aren't
        // stored off-heap.
        blockManager.releaseLock(blockId)
    }
  }

}


private object TorrentBroadcast extends Logging {

  /**
   * A [[KeyLock]] whose key is [[BroadcastBlockId]] to ensure there is only one thread fetching
   * the same [[TorrentBroadcast]] block.
   */
  private val torrentBroadcastLock = new KeyLock[BroadcastBlockId]

  def blockifyObject[T: ClassTag](
      obj: T,
      blockSize: Int,
      serializer: Serializer,
      compressionCodec: Option[CompressionCodec]): Array[ByteBuffer] = {
    val cbbos = new ChunkedByteBufferOutputStream(blockSize, ByteBuffer.allocate)
    val out = compressionCodec.map(c => c.compressedOutputStream(cbbos)).getOrElse(cbbos)
    val ser = serializer.newInstance()
    val serOut = ser.serializeStream(out)
    Utils.tryWithSafeFinally {
      serOut.writeObject[T](obj)
    } {
      serOut.close()
    }
    cbbos.toChunkedByteBuffer.getChunks()
  }

  def unBlockifyObject[T: ClassTag](
      blocks: Array[InputStream],
      serializer: Serializer,
      compressionCodec: Option[CompressionCodec]): T = {
    require(blocks.nonEmpty, "Cannot unblockify an empty array of blocks")
    val is = new SequenceInputStream(blocks.iterator.asJavaEnumeration)
    val in: InputStream = compressionCodec.map(c => c.compressedInputStream(is)).getOrElse(is)
    val ser = serializer.newInstance()
    val serIn = ser.deserializeStream(in)
    val obj = Utils.tryWithSafeFinally {
      serIn.readObject[T]()
    } {
      serIn.close()
    }
    obj
  }

  /**
   * Remove all persisted blocks associated with this torrent broadcast on the executors.
   * If removeFromDriver is true, also remove these persisted blocks on the driver.
   */
  def unpersist(id: Long, removeFromDriver: Boolean, blocking: Boolean): Unit = {
    logDebug(s"Unpersisting TorrentBroadcast $id")
    SparkEnv.get.blockManager.master.removeBroadcast(id, removeFromDriver, blocking)
  }
}

```

```scala
//### blockManager.putSingle(broadcastId, value, MEMORY_AND_DISK, tellMaster = false) ###
// 最后调用的是：
  def putIterator[T: ClassTag](
      blockId: BlockId,
      values: Iterator[T],
      level: StorageLevel,
      tellMaster: Boolean = true): Boolean = {
    require(values != null, "Values is null")
    doPutIterator(blockId, () => values, level, implicitly[ClassTag[T]], tellMaster) match {
      case None => //说明存储成功
        true
      case Some(iter) => // 存储失败，我们需要把迭代器关闭，释放内存
        iter.close()
        false
    }
  }

// 上一步实现的核心方法：
// ##doPutIterator(blockId, () => values, level, implicitly[ClassTag[T]], tellMaster) ##
// 成功返回None 失败返回迭代器用于调用关闭
  private def doPutIterator[T](
      blockId: BlockId,
      iterator: () => Iterator[T],
      level: StorageLevel,
      classTag: ClassTag[T],
      tellMaster: Boolean = true,
      keepReadLock: Boolean = false): Option[PartiallyUnrolledIterator[T]] = {
    doPut(blockId, level, classTag, tellMaster = tellMaster, keepReadLock = keepReadLock)
 { info => // 这个info代表 blockinfo 保存有 存储等级、是否通知master节点、类标签（用于序列化器选择）
      val startTimeNs = System.nanoTime()
      var iteratorFromFailedMemoryStorePut: Option[PartiallyUnrolledIterator[T]] = None
      // Size of the block in bytes
      var size = 0L
      if (level.useMemory) {
        // Put it in memory first, even if it also has useDisk set to true;
        // We will drop it to disk later if the memory store can't hold it.
        if (level.deserialized) { // 当已经反序列化时
          memoryStore.putIteratorAsValues(blockId, iterator(), classTag) match {
            case Right(s) =>
              size = s
            case Left(iter) =>
              // Not enough space to unroll this block; drop to disk if applicable
              if (level.useDisk) { // 此分支表示内存不够并且该变量支持磁盘存储
                logWarning(s"Persisting block $blockId to disk instead.")
                diskStore.put(blockId) { channel =>
                  val out = Channels.newOutputStream(channel)
                  serializerManager.dataSerializeStream(blockId, out, iter)(classTag)
                }
                size = diskStore.getSize(blockId)
              } else {
                // 内存不足并且也不支持磁盘存储 则包装成PartiallyUnrolledIterator 用于回收内存
                iteratorFromFailedMemoryStorePut = Some(iter)
              }
          }
        } else { // 已经序列化时
          memoryStore.putIteratorAsBytes(blockId, iterator(), classTag, level.memoryMode) match {
            case Right(s) => //返回已经保存的数据的真实大小
              size = s
            case Left(partiallySerializedValues) =>
              // 如果可以存储等级可以保存到磁盘，则存储之
              if (level.useDisk) {
                logWarning(s"Persisting block $blockId to disk instead.")
                diskStore.put(blockId) { channel =>
                  val out = Channels.newOutputStream(channel)
                  partiallySerializedValues.finishWritingToStream(out)
                }
                size = diskStore.getSize(blockId)
              } else {
                // 否则返回包装的迭代器
                iteratorFromFailedMemoryStorePut = Some(partiallySerializedValues.valuesIterator)
              }
          }
        }

      } else if (level.useDisk) { // 如果存储等级只为磁盘的话 存储在磁盘中
        diskStore.put(blockId) { channel =>
          val out = Channels.newOutputStream(channel)
          serializerManager.dataSerializeStream(blockId, out, iterator())(classTag)
        }
        size = diskStore.getSize(blockId)
      }

      val putBlockStatus = getCurrentBlockStatus(blockId, info)
      val blockWasSuccessfullyStored = putBlockStatus.storageLevel.isValid
      if (blockWasSuccessfullyStored) {
        // Now that the block is in either the memory or disk store, tell the master about it.
        info.size = size
        if (tellMaster && info.tellMaster) {
          reportBlockStatus(blockId, putBlockStatus)
        }
        addUpdatedBlockStatusToTaskMetrics(blockId, putBlockStatus)
        logDebug(s"Put block $blockId locally took ${Utils.getUsedTimeNs(startTimeNs)}")
        if (level.replication > 1) { //维护副本数量
          val remoteStartTimeNs = System.nanoTime()
          val bytesToReplicate = doGetLocalBytes(blockId, info)
          // [SPARK-16550] Erase the typed classTag when using default serialization, since
          // NettyBlockRpcServer crashes when deserializing repl-defined classes.
          // TODO(ekl) remove this once the classloader issue on the remote end is fixed.
          val remoteClassTag = if (!serializerManager.canUseKryo(classTag)) {
            scala.reflect.classTag[Any]
          } else {
            classTag
          }
          try {
            replicate(blockId, bytesToReplicate, level, remoteClassTag)
          } finally {
            bytesToReplicate.dispose()
          }
          logDebug(s"Put block $blockId remotely took ${Utils.getUsedTimeNs(remoteStartTimeNs)}")
        }
      }
      assert(blockWasSuccessfullyStored == iteratorFromFailedMemoryStorePut.isEmpty)
      iteratorFromFailedMemoryStorePut
    }
  }

```

```scala

// ############### org.apache.spark.storage.memory.MemoryStore#putIterator ##############
private def putIterator[T](
      blockId: BlockId,
      values: Iterator[T],
      classTag: ClassTag[T],
      memoryMode: MemoryMode,
      valuesHolder: ValuesHolder[T]): Either[Long, Long] = {
    require(!contains(blockId), s"Block $blockId is already present in the MemoryStore")

    // Number of elements unrolled so far
    var elementsUnrolled = 0
    // Whether there is still enough memory for us to continue unrolling this block
    var keepUnrolling = true
    // Initial per-task memory to request for unrolling blocks (bytes). 1M
    val initialMemoryThreshold = unrollMemoryThreshold
    // How often to check whether we need to request more memory
    val memoryCheckPeriod = conf.get(UNROLL_MEMORY_CHECK_PERIOD)
    // Memory currently reserved by this task for this particular unrolling operation
    var memoryThreshold = initialMemoryThreshold
    // Memory to request as a multiple of current vector size  // 容量扩张因子 1.5
    val memoryGrowthFactor = conf.get(UNROLL_MEMORY_GROWTH_FACTOR)

    var unrollMemoryUsedByThisBlock = 0L // 已经使用的内存

    // Request enough memory to begin unrolling
    keepUnrolling =
      reserveUnrollMemoryForThisTask(blockId, initialMemoryThreshold, memoryMode)

    if (!keepUnrolling) {
      logWarning(s"Failed to reserve initial memory threshold of " +
        s"${Utils.bytesToString(initialMemoryThreshold)} for computing block $blockId in memory.")
    } else {
      unrollMemoryUsedByThisBlock += initialMemoryThreshold
    }

    // 周期性检查 实际使用的内存 是否超过 申请的内存
    while (values.hasNext && keepUnrolling) {
        
      // * 存储逻辑位于此处 SerializedValuesHolder.storeValue *
      valuesHolder.storeValue(values.next())
      if (elementsUnrolled % memoryCheckPeriod == 0) {
        val currentSize = valuesHolder.estimatedSize()
        // If our vector's size has exceeded the threshold, request more memory
        if (currentSize >= memoryThreshold) {
          val amountToRequest = (currentSize * memoryGrowthFactor - memoryThreshold).toLong
          keepUnrolling =
            reserveUnrollMemoryForThisTask(blockId, amountToRequest, memoryMode)
          if (keepUnrolling) {
            unrollMemoryUsedByThisBlock += amountToRequest
          }
          // New threshold is currentSize * memoryGrowthFactor
          memoryThreshold += amountToRequest
        }
      }
      elementsUnrolled += 1
    }

    // Make sure that we have enough memory to store the block. By this point, it is possible that
    // the block's actual memory usage has exceeded the unroll memory by a small amount, so we
    // perform one final call to attempt to allocate additional memory if necessary.
    if (keepUnrolling) {
      val entryBuilder = valuesHolder.getBuilder()
      val size = entryBuilder.preciseSize
      if (size > unrollMemoryUsedByThisBlock) {
        val amountToRequest = size - unrollMemoryUsedByThisBlock
        keepUnrolling = reserveUnrollMemoryForThisTask(blockId, amountToRequest, memoryMode)
        if (keepUnrolling) {
          unrollMemoryUsedByThisBlock += amountToRequest
        }
      }

      if (keepUnrolling) {
        val entry = entryBuilder.build()
        // Synchronize so that transfer is atomic
        memoryManager.synchronized {
          // 释放展开对象所用的内存， 申请存储对象的内存
          /**
        展开对象所用的内存是什么？ 举个例子,你查询数据库得到一个迭代器,你想把这些数据缓存.
你不能只缓存这个迭代器,因为它可能是从数据库一行行去拿数据,你需要调用 Iterator.toList,但是这样一下子拿来了很多数据,一下子把内存撑爆了,unrollMemory这部分就用来展开迭代器的内存.
          */
          releaseUnrollMemoryForThisTask(memoryMode, unrollMemoryUsedByThisBlock)
          val success = memoryManager.acquireStorageMemory(blockId, entry.size, memoryMode)
          assert(success, "transferring unroll memory to storage memory failed")
        }

        entries.synchronized {
          entries.put(blockId, entry) // 将保存的entry保存在LinkedHashMap[BlockId, MemoryEntry[_]]中
        }

        logInfo("Block %s stored as values in memory (estimated size %s, free %s)".format(blockId,
          Utils.bytesToString(entry.size), Utils.bytesToString(maxMemory - blocksMemoryUsed)))
        Right(entry.size)
      } else {
        // We ran out of space while unrolling the values for this block
        logUnrollFailureMessage(blockId, entryBuilder.preciseSize)
        Left(unrollMemoryUsedByThisBlock)
      }
    } else {
      // We ran out of space while unrolling the values for this block
      logUnrollFailureMessage(blockId, valuesHolder.estimatedSize())
      Left(unrollMemoryUsedByThisBlock)
    }
  }
```

## 文件写入

这一部分的写入是利用hadoop的API完成的 正在深入理解



前面所说的磁盘管理只是针对每个executor说的

```scala
// ###################### org.apache.spark.internal.io.SparkHadoopWriter ################
/**
 * A helper object that saves an RDD using a Hadoop OutputFormat.
 */
private[spark]
object SparkHadoopWriter extends Logging {
  import SparkHadoopWriterUtils._

/**
Basic work flow of this command is:
 1. Driver side setup, prepare the data source and hadoop configuration for the write 		job to be issued.
 2. Issues a write job consists of one or more executor side tasks, each of which writes     all rows within an RDD partition.
 3. If no exception is thrown in a task, commits that task, otherwise aborts that task;       If any exception is thrown during task commitment, also aborts that task.
 4. If all tasks are committed, commit the job, otherwise aborts the job;  If any             exception is thrown during job commitment, also aborts the job.
*/
  def write[K, V: ClassTag](
      rdd: RDD[(K, V)],
      config: HadoopWriteConfigUtil[K, V]): Unit = {
    // Extract context and configuration from RDD.
    val sparkContext = rdd.context
    val commitJobId = rdd.id

    // Set up a job.
    val jobTrackerId = createJobTrackerID(new Date())
    val jobContext = config.createJobContext(jobTrackerId, commitJobId)
    config.initOutputFormat(jobContext)

    // Assert the output format/key/value class is set in JobConf.
    config.assertConf(jobContext, rdd.conf)

    // propagate the description UUID into the jobs, so that committers
    // get an ID guaranteed to be unique.
    jobContext.getConfiguration.set("spark.sql.sources.writeJobUUID",
      UUID.randomUUID.toString)

    val committer = config.createCommitter(commitJobId)
    committer.setupJob(jobContext)

    // Try to write all RDD partitions as a Hadoop OutputFormat.
    try {
      val ret = sparkContext.runJob(rdd, (context: TaskContext, iter: Iterator[(K, V)]) => {
        // SPARK-24552: Generate a unique "attempt ID" based on the stage and task attempt numbers.
        // Assumes that there won't be more than Short.MaxValue attempts, at least not concurrently.
        val attemptId = (context.stageAttemptNumber << 16) | context.attemptNumber

        executeTask(
          context = context,
          config = config,
          jobTrackerId = jobTrackerId,
          commitJobId = commitJobId,
          sparkPartitionId = context.partitionId,
          sparkAttemptNumber = attemptId,
          committer = committer,
          iterator = iter)
      })

      committer.commitJob(jobContext, ret)
      logInfo(s"Job ${jobContext.getJobID} committed.")
    } catch {
      case cause: Throwable =>
        logError(s"Aborting job ${jobContext.getJobID}.", cause)
        committer.abortJob(jobContext)
        throw new SparkException("Job aborted.", cause)
    }
  }

  /** Write a RDD partition out in a single Spark task. */
  private def executeTask[K, V: ClassTag](
      context: TaskContext,
      config: HadoopWriteConfigUtil[K, V],
      jobTrackerId: String,
      commitJobId: Int,
      sparkPartitionId: Int,
      sparkAttemptNumber: Int,
      committer: FileCommitProtocol,
      iterator: Iterator[(K, V)]): TaskCommitMessage = {
    // Set up a task.
    val taskContext = config.createTaskAttemptContext(
      jobTrackerId, commitJobId, sparkPartitionId, sparkAttemptNumber)
    committer.setupTask(taskContext)

    // Initiate the writer.
    config.initWriter(taskContext, sparkPartitionId)
    var recordsWritten = 0L

    // We must initialize the callback for calculating bytes written after the statistic table
    // is initialized in FileSystem which is happened in initWriter.
    val (outputMetrics, callback) = initHadoopOutputMetrics(context)

    // Write all rows in RDD partition.
    try {
      val ret = Utils.tryWithSafeFinallyAndFailureCallbacks {
        while (iterator.hasNext) {
          val pair = iterator.next()
          config.write(pair)

          // Update bytes written metric every few records
          maybeUpdateOutputMetrics(outputMetrics, callback, recordsWritten)
          recordsWritten += 1
        }

        config.closeWriter(taskContext)
        committer.commitTask(taskContext)
      }(catchBlock = {
        // If there is an error, release resource and then abort the task.
        try {
          config.closeWriter(taskContext)
        } finally {
          committer.abortTask(taskContext)
          logError(s"Task ${taskContext.getTaskAttemptID} aborted.")
        }
      })

      outputMetrics.setBytesWritten(callback())
      outputMetrics.setRecordsWritten(recordsWritten)

      ret
    } catch {
      case t: Throwable =>
        throw new SparkException("Task failed while writing rows", t)
    }
  }
}

/**
 * A helper class that reads JobConf from older mapred API, creates output Format/Committer/Writer.
 */
private[spark]
class HadoopMapRedWriteConfigUtil[K, V: ClassTag](conf: SerializableJobConf)
  extends HadoopWriteConfigUtil[K, V] with Logging {

  private var outputFormat: Class[_ <: OutputFormat[K, V]] = null
  private var writer: RecordWriter[K, V] = null

  private def getConf: JobConf = conf.value

  // --------------------------------------------------------------------------
  // Create JobContext/TaskAttemptContext
  // --------------------------------------------------------------------------

  override def createJobContext(jobTrackerId: String, jobId: Int): NewJobContext = {
    val jobAttemptId = new SerializableWritable(new JobID(jobTrackerId, jobId))
    new JobContextImpl(getConf, jobAttemptId.value)
  }

  override def createTaskAttemptContext(
      jobTrackerId: String,
      jobId: Int,
      splitId: Int,
      taskAttemptId: Int): NewTaskAttemptContext = {
    // Update JobConf.
    HadoopRDD.addLocalConfiguration(jobTrackerId, jobId, splitId, taskAttemptId, conf.value)
    // Create taskContext.
    val attemptId = new TaskAttemptID(jobTrackerId, jobId, TaskType.MAP, splitId, taskAttemptId)
    new TaskAttemptContextImpl(getConf, attemptId)
  }

  // --------------------------------------------------------------------------
  // Create committer
  // --------------------------------------------------------------------------

  override def createCommitter(jobId: Int): HadoopMapReduceCommitProtocol = {
    // Update JobConf.
    HadoopRDD.addLocalConfiguration("", 0, 0, 0, getConf)
    // Create commit protocol.
    FileCommitProtocol.instantiate(
      className = classOf[HadoopMapRedCommitProtocol].getName,
      jobId = jobId.toString,
      outputPath = getConf.get("mapred.output.dir")
    ).asInstanceOf[HadoopMapReduceCommitProtocol]
  }

  // --------------------------------------------------------------------------
  // Create writer
  // --------------------------------------------------------------------------

  override def initWriter(taskContext: NewTaskAttemptContext, splitId: Int): Unit = {
    val numfmt = NumberFormat.getInstance(Locale.US)
    numfmt.setMinimumIntegerDigits(5)
    numfmt.setGroupingUsed(false)

    val outputName = "part-" + numfmt.format(splitId)
    val path = FileOutputFormat.getOutputPath(getConf)
    val fs: FileSystem = {
      if (path != null) {
        path.getFileSystem(getConf)
      } else {
        FileSystem.get(getConf)
      }
    }

    writer = getConf.getOutputFormat
      .getRecordWriter(fs, getConf, outputName, Reporter.NULL)
      .asInstanceOf[RecordWriter[K, V]]

    require(writer != null, "Unable to obtain RecordWriter")
  }

  override def write(pair: (K, V)): Unit = {
    require(writer != null, "Must call createWriter before write.")
    writer.write(pair._1, pair._2)
  }

  override def closeWriter(taskContext: NewTaskAttemptContext): Unit = {
    if (writer != null) {
      writer.close(Reporter.NULL)
    }
  }

  // --------------------------------------------------------------------------
  // Create OutputFormat
  // --------------------------------------------------------------------------

  override def initOutputFormat(jobContext: NewJobContext): Unit = {
    if (outputFormat == null) {
      outputFormat = getConf.getOutputFormat.getClass
        .asInstanceOf[Class[_ <: OutputFormat[K, V]]]
    }
  }

  private def getOutputFormat(): OutputFormat[K, V] = {
    require(outputFormat != null, "Must call initOutputFormat first.")

    outputFormat.getConstructor().newInstance()
  }

  // --------------------------------------------------------------------------
  // Verify hadoop config
  // --------------------------------------------------------------------------

  override def assertConf(jobContext: NewJobContext, conf: SparkConf): Unit = {
    val outputFormatInstance = getOutputFormat()
    val keyClass = getConf.getOutputKeyClass
    val valueClass = getConf.getOutputValueClass
    if (outputFormatInstance == null) {
      throw new SparkException("Output format class not set")
    }
    if (keyClass == null) {
      throw new SparkException("Output key class not set")
    }
    if (valueClass == null) {
      throw new SparkException("Output value class not set")
    }
    SparkHadoopUtil.get.addCredentials(getConf)

    logDebug("Saving as hadoop file of type (" + keyClass.getSimpleName + ", " +
      valueClass.getSimpleName + ")")

    if (SparkHadoopWriterUtils.isOutputSpecValidationEnabled(conf)) {
      // FileOutputFormat ignores the filesystem parameter
      val ignoredFs = FileSystem.get(getConf)
      getOutputFormat().checkOutputSpecs(ignoredFs, getConf)
    }
  }
}

/**
 * A helper class that reads Configuration from newer mapreduce API, creates output
 * Format/Committer/Writer.
 */
private[spark]
class HadoopMapReduceWriteConfigUtil[K, V: ClassTag](conf: SerializableConfiguration)
  extends HadoopWriteConfigUtil[K, V] with Logging {

  private var outputFormat: Class[_ <: NewOutputFormat[K, V]] = null
  private var writer: NewRecordWriter[K, V] = null

  private def getConf: Configuration = conf.value

  // --------------------------------------------------------------------------
  // Create JobContext/TaskAttemptContext
  // --------------------------------------------------------------------------

  override def createJobContext(jobTrackerId: String, jobId: Int): NewJobContext = {
    val jobAttemptId = new NewTaskAttemptID(jobTrackerId, jobId, TaskType.MAP, 0, 0)
    new NewTaskAttemptContextImpl(getConf, jobAttemptId)
  }

  override def createTaskAttemptContext(
      jobTrackerId: String,
      jobId: Int,
      splitId: Int,
      taskAttemptId: Int): NewTaskAttemptContext = {
    val attemptId = new NewTaskAttemptID(
      jobTrackerId, jobId, TaskType.REDUCE, splitId, taskAttemptId)
    new NewTaskAttemptContextImpl(getConf, attemptId)
  }

  // --------------------------------------------------------------------------
  // Create committer
  // --------------------------------------------------------------------------

  override def createCommitter(jobId: Int): HadoopMapReduceCommitProtocol = {
    FileCommitProtocol.instantiate(
      className = classOf[HadoopMapReduceCommitProtocol].getName,
      jobId = jobId.toString,
      outputPath = getConf.get("mapreduce.output.fileoutputformat.outputdir")
    ).asInstanceOf[HadoopMapReduceCommitProtocol]
  }

  // --------------------------------------------------------------------------
  // Create writer
  // --------------------------------------------------------------------------

  override def initWriter(taskContext: NewTaskAttemptContext, splitId: Int): Unit = {
    val taskFormat = getOutputFormat()
    // If OutputFormat is Configurable, we should set conf to it.
    taskFormat match {
      case c: Configurable => c.setConf(getConf)
      case _ => ()
    }

    writer = taskFormat.getRecordWriter(taskContext)
      .asInstanceOf[NewRecordWriter[K, V]]

    require(writer != null, "Unable to obtain RecordWriter")
  }

  override def write(pair: (K, V)): Unit = {
    require(writer != null, "Must call createWriter before write.")
    writer.write(pair._1, pair._2)
  }

  override def closeWriter(taskContext: NewTaskAttemptContext): Unit = {
    if (writer != null) {
      writer.close(taskContext)
      writer = null
    } else {
      logWarning("Writer has been closed.")
    }
  }

  // --------------------------------------------------------------------------
  // Create OutputFormat
  // --------------------------------------------------------------------------

  override def initOutputFormat(jobContext: NewJobContext): Unit = {
    if (outputFormat == null) {
      outputFormat = jobContext.getOutputFormatClass
        .asInstanceOf[Class[_ <: NewOutputFormat[K, V]]]
    }
  }

  private def getOutputFormat(): NewOutputFormat[K, V] = {
    require(outputFormat != null, "Must call initOutputFormat first.")

    outputFormat.getConstructor().newInstance()
  }

  // --------------------------------------------------------------------------
  // Verify hadoop config
  // --------------------------------------------------------------------------

  override def assertConf(jobContext: NewJobContext, conf: SparkConf): Unit = {
    if (SparkHadoopWriterUtils.isOutputSpecValidationEnabled(conf)) {
      getOutputFormat().checkOutputSpecs(jobContext)
    }
  }
}

```



## 日志分析

```scala
 // 因为在本地模式下 会利用线程池来进行数据的写入，还没想好怎么strace
```

