local env = std.extVar("__ksonnet/environments");
local params = std.extVar("__ksonnet/params").components.mycnnjob;
// We need at least 1 parameter server.

// TODO(jlewi): Should we move this into an examples package?

local k = import "k.libsonnet";
local deployment = k.extensions.v1beta1.deployment;
local container = deployment.mixin.spec.template.spec.containersType;
local podTemplate = k.extensions.v1beta1.podTemplate;

// updatedParams uses the environment namespace if
// the namespace parameter is not explicitly set
local updatedParams = params {
  namespace: if params.namespace == "null" then env.namespace else params.namespace
};

local tfJob = import "kubeflow/tf-job/tf-job.libsonnet";

local name = params.name;
local namespace = updatedParams.namespace;

local numGpus = params.num_gpus;
local batchSize = params.batch_size;
local model = params.model;

local args = [
               "python",
               "tf_cnn_benchmarks.py",
               "--batch_size=" + batchSize,
               "--model=" + model,
               "--variable_update=parameter_server",
               "--flush_stdout=true",
             ] +
             if numGpus == 0 then
               // We need to set num_gpus=1 even if not using GPUs because otherwise the devie list
               // is empty because of this code
               // https://github.com/tensorflow/benchmarks/blob/master/scripts/tf_cnn_benchmarks/benchmark_cnn.py#L775
               // We won't actually use GPUs because based on other flags no ops will be assigned to GPus.
               [
                 "--num_gpus=1",
                 "--local_parameter_device=cpu",
                 "--device=cpu",
                 "--data_format=NHWC",
               ]
             else
               [
                 "--num_gpus=" + numGpus,
               ]
;

local image = params.image;
local imageGpu = params.image_gpu;
local numPs = params.num_ps;
local numWorkers = params.num_workers;
local numGpus = params.num_gpus;

local workerSpec = if numGpus > 0 then
  tfJob.parts.tfJobReplica("WORKER", numWorkers, args, imageGpu, numGpus)
else
  tfJob.parts.tfJobReplica("WORKER", numWorkers, args, image);

// TODO(jlewi): Look at how the redis prototype modifies a container by
// using mapContainersWithName. Can we do something similar?
// https://github.com/ksonnet/parts/blob/9d78d6bb445d530d5b927656d2293d4f12654608/incubator/redis/redis.libsonnet
local replicas = std.map(function(s)
                           s {
                             template+: {
                               spec+: {
                                 // TODO(jlewi): Does this overwrite containers?
                                 containers: [
                                   s.template.spec.containers[0] {
                                     workingDir: "/opt/tf-benchmarks/scripts/tf_cnn_benchmarks",
                                   },
                                 ],
                               },
                             },
                           },
                         std.prune([workerSpec, tfJob.parts.tfJobReplica("PS", numPs, args, image)]));

local job =
  if numWorkers < 1 then
    error "num_workers must be >= 1"
  else
    if numPs < 1 then
      error "num_ps must be >= 1"
    else
      tfJob.parts.tfJob(name, namespace, replicas, null) + {
        spec+: {
          tfImage: image,
          terminationPolicy: { chief: { replicaName: "WORKER", replicaIndex: 0 } },
        },
      };

std.prune(k.core.v1.list.new([job]))
