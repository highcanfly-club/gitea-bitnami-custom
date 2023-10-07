allow_k8s_contexts('kubernetesOCI')
sha1=str(local("cat Dockerfile | openssl dgst -sha1 -r | awk '{print $1}' | tr -d '\n'"))
Namespace='sandbox-gitea-dev'
ModuleName='my_module'
ModulePath='./'+ModuleName
Registry='ttl.sh/sanbox-gitea-dev-'+sha1
default_registry(Registry)

load('ext://helm_resource', 'helm_resource', 'helm_repo')
load('ext://namespace', 'namespace_create')
os.putenv ( 'NAMESPACE' , Namespace )
os.putenv ( 'MODULENAME', ModuleName )
os.putenv ('MODULEPATH', ModulePath)
os.putenv ( 'DOCKER_REGISTRY' , Registry ) 
namespace_create(Namespace)

custom_build('gitea_bitnami_custom_tilted', './kaniko-build.sh', [
    ModuleName
], skips_local_docker = True,
    live_update = [
        sync(ModulePath, '/dev-addons/'+ModuleName)
    ])

helm_resource('gitea-dev',
    'helm/gitea',
    namespace = Namespace,
    flags = ['--values=./_values_gitea.yaml', '--set', 'gitea.image.registry=ttl.sh'],
    image_deps = ['gitea_bitnami_custom_tilted'],
    image_keys=[('gitea.image.registry','gitea.image.repository', 'gitea.image.tag')],
)
load('ext://uibutton', 'cmd_button', 'location')

cmd_button(name='push module',
           resource='gitea-dev',
           argv=['find', ModuleName , '-exec', 'touch', '{}','+'])
