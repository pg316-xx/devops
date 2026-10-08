#!/bin/bash
# rmq01: RabbitMQ with user "test"
set -e

dnf install -y epel-release
dnf install -y wget centos-release-rabbitmq-38
dnf --enablerepo=centos-rabbitmq-38 install -y rabbitmq-server
systemctl enable --now rabbitmq-server

# Allow remote (non-localhost) logins, create app user
echo "[{rabbit, [{loopback_users, []}]}]." > /etc/rabbitmq/rabbitmq.config
rabbitmqctl add_user test test || true
rabbitmqctl set_user_tags test administrator
rabbitmqctl set_permissions -p / test ".*" ".*" ".*"
systemctl restart rabbitmq-server

# Firewall: allow AMQP port
systemctl enable --now firewalld
firewall-cmd --permanent --add-port=5672/tcp
firewall-cmd --reload
