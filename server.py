import os

import docker
from aiohttp import web

DOCKER_IMAGE = os.getenv('DOCKER_IMAGE', 'guamulo/openvpn')
OVPN_DATA = os.getenv('OVPN_DATA', f'{os.getcwd()}/ovpn-data')


async def handle_create(request):
    post = await request.json()
    user = post.get('user')
    client = docker.from_env()
    client.containers.run(image=DOCKER_IMAGE, command=f"easyrsa build-client-full {user} nopass", remove=True,
                          volumes={OVPN_DATA: {'bind': '/etc/openvpn', 'mode': 'rw'}})
    output = client.containers.run(image=DOCKER_IMAGE, command=f"ovpn_getclient {user}",
                                   remove=True,
                                   detach=False,
                                   volumes={OVPN_DATA: {'bind': '/etc/openvpn', 'mode': 'rw'}},
                                   stdout=True)
    return web.Response(text=output.decode('ascii'))


async def handle_revoke(request):
    post = await request.json()
    user = post.get('user')
    client = docker.from_env()
    client.containers.run(image=DOCKER_IMAGE, command=f"bash -c \"echo 'yes' | ovpn_revokeclient {user}\"",
                          remove=True,
                          volumes={OVPN_DATA: {'bind': '/etc/openvpn', 'mode': 'rw'}})
    return web.Response(text='ok')


async def handle_healthcheck(request):
    return web.Response(text='alive')


if __name__ == '__main__':
    app = web.Application()
    app.add_routes([web.post('/create', handle_create)])
    app.add_routes([web.post('/revoke', handle_revoke)])
    app.add_routes([web.get('/healthcheck', handle_healthcheck)])

    web.run_app(app, host='0.0.0.0', port=5000)
