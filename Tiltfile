allow_k8s_contexts('kubernetes-admin@kubernetes')
if os.name == 'nt':
    datebase=str(local("powershell -command Get-Date -Format yyyy-MM-dd"))
elif os.name == 'posix':
    datebase=str(local("date -I"))

datei=str(abs(hash(datebase)))
sha1=str(abs(hash(str(local("openssl dgst -sha1 Dockerfile")))))
Namespace='sandbox-gitea-dev'
ModuleName='my_module'
ModulePath='./'+ModuleName
CacheRegistry='ttl.sh/sanbox-gitea-dev-'+datei+'-cache'
Registry='ttl.sh/sanbox-gitea-dev-'+sha1
default_registry(Registry)

load('ext://helm_resource', 'helm_resource', 'helm_repo')
load('ext://namespace', 'namespace_create')
os.putenv ( 'NAMESPACE' , Namespace )
os.putenv ( 'MODULENAME', ModuleName )
os.putenv ('MODULEPATH', ModulePath)
os.putenv ( 'DOCKER_REGISTRY' , Registry ) 
os.putenv ( 'DOCKER_CACHE_REGISTRY' , CacheRegistry ) 
namespace_create(Namespace)

warn ("sha1: "+sha1)
warn ("datei: "+datei)
if os.name == 'nt':
    # Code à exécuter si le système d'exploitation est Windows
    warn("Running on Windows")
    custom_build('gitea_bitnami_custom_tilted', 'kubectl -n %NAMESPACE% delete pod/kaniko & tar -cvz --exclude "node_modules" --exclude "dkim.rsa" --exclude "private" --exclude "k8s" --exclude ".git" --exclude ".github" --exclude-vcs --exclude ".docker" --exclude "_sensitive_datas" -f - \
    ./Dockerfile libgitea.sh gitea-env.sh ./busybox autobackup.sh | kubectl -n %NAMESPACE% run kaniko --image=gcr.io/kaniko-project/executor:v1.19.2 --stdin=true --command -- /kaniko/executor -v info --dockerfile=Dockerfile --context=tar://stdin --destination=%EXPECTED_REF% --cache=true --cache-ttl=4h --cache-repo=%DOCKER_CACHE_REGISTRY%', [
            ModuleName
        ], skips_local_docker = True)
elif os.name == 'posix':
    # Code à exécuter si le système d'exploitation est Linux ou MacOS
    warn("Running on Posix")
    custom_build('gitea_bitnami_custom_tilted', 'kubectl -n $NAMESPACE delete pod/kaniko ; tar -cvz --exclude "node_modules" --exclude "dkim.rsa" --exclude "private" --exclude "k8s" --exclude ".git" --exclude ".github" --exclude-vcs --exclude ".docker" --exclude "_sensitive_datas" -f - \
  ./Dockerfile libgitea.sh gitea-env.sh ./busybox autobackup.sh | kubectl -n $NAMESPACE run kaniko --image=gcr.io/kaniko-project/executor:v1.19.2 --stdin=true --command -- /kaniko/executor -v info --dockerfile=Dockerfile --context=tar://stdin --destination=$EXPECTED_REF --cache=true --cache-ttl=4h --cache-repo=$DOCKER_CACHE_REGISTRY', [
            ModuleName
        ], skips_local_docker = True)

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
