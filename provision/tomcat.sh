#!/bin/bash
# app01: Tomcat + build and deploy the vprofile app
set -e
TOMURL="https://archive.apache.org/dist/tomcat/tomcat-10/v10.1.26/bin/apache-tomcat-10.1.26.tar.gz"
MAVENURL="https://archive.apache.org/dist/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.zip"

dnf install -y java-17-openjdk java-17-openjdk-devel git wget unzip zip rsync

# Install Tomcat into /usr/local/tomcat, run as user "tomcat"
cd /tmp
wget -q "$TOMURL" -O tomcatbin.tar.gz
TOMDIR=$(tar tzf tomcatbin.tar.gz | head -1 | cut -d/ -f1)
tar xzf tomcatbin.tar.gz
id tomcat &>/dev/null || useradd --shell /sbin/nologin tomcat
rsync -a /tmp/$TOMDIR/ /usr/local/tomcat/
chown -R tomcat:tomcat /usr/local/tomcat

cat > /etc/systemd/system/tomcat.service <<EOT
[Unit]
Description=Tomcat
After=network.target

[Service]
User=tomcat
Group=tomcat
WorkingDirectory=/usr/local/tomcat
Environment=JAVA_HOME=/usr/lib/jvm/jre
Environment=CATALINA_HOME=/usr/local/tomcat
Environment=CATALINA_BASE=/usr/local/tomcat
ExecStart=/usr/local/tomcat/bin/catalina.sh run
ExecStop=/usr/local/tomcat/bin/shutdown.sh
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOT

systemctl daemon-reload
systemctl enable tomcat

# Install Maven and build the app
cd /tmp
wget -q "$MAVENURL" -O maven.zip
unzip -qo maven.zip
rm -rf /usr/local/maven3.9
cp -r apache-maven-3.9.9 /usr/local/maven3.9
export MAVEN_OPTS="-Xmx512m"

rm -rf vprofile-project
git clone -b local https://github.com/hkhcoder/vprofile-project.git
cd vprofile-project
/usr/local/maven3.9/bin/mvn -q install -DskipTests

# Deploy the WAR as the root app
systemctl stop tomcat || true
rm -rf /usr/local/tomcat/webapps/ROOT*
cp target/vprofile-v2.war /usr/local/tomcat/webapps/ROOT.war
chown tomcat:tomcat /usr/local/tomcat/webapps/ROOT.war
systemctl start tomcat

# Firewall: allow Tomcat port
systemctl enable --now firewalld
firewall-cmd --permanent --add-port=8080/tcp
firewall-cmd --reload
