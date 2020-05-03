OVPN_DATA ?= $(PWD)/"ovpn-data"
SERVER_ADDRESS ?= "192.168.0.56"
CA ?= "myvpn"
DOCKER_IMAGE ?= kylemanna/openvpn
REPOSITORY ?= https://github.com/kylemanna/docker-openvpn.git
EXAMPLE_USER ?= user1

.PHONY:
build:
	docker build -t vpn2go .
	git clone $(REPOSITORY)
	cd docker-openvpn && docker build -t $(DOCKER_IMAGE) .

.PHONY:
configure:
	docker run --rm -v $(OVPN_DATA):/etc/openvpn $(DOCKER_IMAGE) ovpn_genconfig -u udp://$(SERVER_ADDRESS)
	docker run --rm -v $(OVPN_DATA):/etc/openvpn -i -e "EASYRSA_BATCH=1" -e "EASYRSA_REQ_CN="$(CA) $(DOCKER_IMAGE) ovpn_initpki nopass

.PHONY:
run:
	docker run --name openvpn -v $(OVPN_DATA):/etc/openvpn -d -p 1194:1194/udp --cap-add=NET_ADMIN -d $(DOCKER_IMAGE)
	docker run -e DOCKER_IMAGE=$(DOCKER_IMAGE) -e OVPN_DATA=$(OVPN_DATA) --name vpn2go -v /var/run/docker.sock:/var/run/docker.sock -p 5000:5000 -d vpn2go

.PHONY:
stop:
	docker stop openvpn vpn2go
	docker rm openvpn vpn2go


.PHONY:
create_example_user:
	docker run -v $(OVPN_DATA):/etc/openvpn --log-driver=none --rm $(DOCKER_IMAGE) easyrsa build-client-full $(EXAMPLE_USER) nopass
	docker run -v $(OVPN_DATA):/etc/openvpn --log-driver=none --rm $(DOCKER_IMAGE) ovpn_getclient $(EXAMPLE_USER) > $(EXAMPLE_USER).ovpn

.PHONY:
revoke_example_user:
	docker run --rm -it -v $(OVPN_DATA):/etc/openvpn $(DOCKER_IMAGE) bash -c "echo 'yes' | ovpn_revokeclient $(EXAMPLE_USER)"

.PHONY:
clean:
	rm -Rf docker-openvpn
	rm -Rf $(OVPN_DATA)
	rm -f $(EXAMPLE_USER).ovpn
	docker rmi $(DOCKER_IMAGE)
