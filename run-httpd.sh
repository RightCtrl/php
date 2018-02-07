#!/usr/bin/env bash
# Make sure we're not confused by old, incompletely-shutdown httpd
# context after restarting the container.  httpd won't start correctly
# if it thinks it is already running.

if [[ -z "$TIMEZONE" ]]; then
    TIMEZONE='Asia/Kolkata'
fi

ln -snf /usr/share/zoneinfo/$TIMEZONE /etc/localtime && echo $TIMEZONE > /etc/timezone

if [[ -z "$servn" ]]; then
    servn='rightctrl.com'
fi
if [[ -z "$cname" ]]; then
    cname='www'
fi

dir='/var/www/'
user='apache'
listen='*'

alias=$cname.$servn

if ! mkdir -p $dir$cname_$servn; then
echo "Web directory already Exist !"
else
echo "Web directory created with success !"
fi

chown -R ${user}:${user}  $dir${cname}_$servn
chmod -R 755  $dir${cname}_$servn
mkdir /var/log/${cname}_$servn
mkdir /etc/httpd/sites-available
mkdir /etc/httpd/sites-enabled
mkdir -p ${dir}${cname}_${servn}/logs
mkdir -p ${dir}${cname}_${servn}/public_html
printf "IncludeOptional sites-enabled/${cname}_$servn.conf \n" >> /etc/httpd/conf/httpd.conf



cat >/etc/httpd/sites-enabled/${cname}_$servn.conf <<EOL
#### $cname.$servn
<VirtualHost ${listen}:80>
ServerName ${servn}
ServerAlias ${alias}
DocumentRoot ${dir}${cname}_${servn}/public_html
ErrorLog ${dir}${cname}_${servn}/logs/error.log
CustomLog ${dir}${cname}_${servn}/logs/requests.log combined
<Directory ${dir}${cname}_${servn}/public_html>
#Options Indexes FollowSymLinks MultiViews
Options FollowSymLinks
Options -Indexes
AllowOverride All
Order allow,deny
Allow from all
Require all granted
</Directory>
Alias /fileserver /fileserver
<Directory /fileserver>
<FilesMatch '\.(gif|jpe?g|png)$'>
AllowOverride None
Order allow,deny
Allow from all
Require all granted
</FilesMatch>
</Directory>
</VirtualHost>
EOL

# Enable SSL

printf "IncludeOptional sites-enabled/ssl.${cname}_$servn.conf" >> /etc/httpd/conf/httpd.conf

# the  certificate
SSL_DIR="${dir}${cname}_${servn}/ssl"
# Set the wildcarded domain
# we want to use
DOMAIN="*.$servn"
if [[ -z "$SUBJ" ]]; then
    SUBJ='/C=IN/ST=Kerala/L=MarketPlace/commonName=$DOMAIN'
    #SUBJ="/C=IN/ST=Kerala/O=RightCtrl/localityName=Kochi/commonName=*.rightctrl.com/organizationalUnitName=MarketPlace/emailAddress="
fi

# A blank passphrase
if [[ -z "$PASSPHRASE" ]]; then
    PASSPHRASE=""
fi

# Set our CSR variables
SUBJ="$SUBJ"
# Create our SSL directory
# in case it doesn't exist
mkdir -p "$SSL_DIR"

# Generate our Private Key, CSR and Certificate
openssl genrsa -out "$SSL_DIR/$cname_$servn.key" 2048

openssl req -new -subj $SUBJ -key "$SSL_DIR/$cname_$servn.key" -out $SSL_DIR/$cname_$servn.csr -passin pass:$PASSPHRASE

openssl x509 -req -days 365 -in "$SSL_DIR/$cname_$servn.csr" -signkey "$SSL_DIR/$cname_$servn.key" -out "$SSL_DIR/$cname_$servn.crt"

if ! echo -e "$SSL_DIR/$cname_$servn.key"; then
    echo "Certificate key wasn't created !"
else
    echo "Certificate key created !"
fi
if ! echo -e "$SSL_DIR/$cname_$servn.crt"; then
    echo "Certificate wasn't created !"
else
    echo "Certificate created !"
fi


cat >/etc/httpd/sites-enabled/ssl.${cname}_$servn.conf <<EOL
#### $cname.$servn
<VirtualHost ${listen}:443>
SSLEngine on
SSLCertificateFile $SSL_DIR/$cname_$servn.crt
SSLCertificateKeyFile $SSL_DIR/$cname_$servn.key
ServerName ${servn}
ServerAlias ${alias}
DocumentRoot ${dir}${cname}_${servn}/public_html
ErrorLog ${dir}${cname}_${servn}/logs/error.log
CustomLog ${dir}${cname}_${servn}/logs/requests.log combined
<Directory ${dir}${cname}_${servn}/public_html>
#Options Indexes FollowSymLinks MultiViews
Options FollowSymLinks
Options -Indexes
AllowOverride All
Order allow,deny
Allow from all
Require all granted
</Directory>
Alias /fileserver /fileserver
<Directory /fileserver>
<FilesMatch '\.(gif|jpe?g|png)$'>
AllowOverride None
Order allow,deny
Allow from all
Require all granted
</FilesMatch>
</Directory>
</VirtualHost>
EOL

if ! echo -e /etc/httpd/sites-enabled/ssl.${cname}_$servn.conf; then
        echo "SSL Virtual host wasn't created !"
else
        echo "SSL Virtual host created !"
fi

rm -rf /run/httpd/* /tmp/httpd*

exec /usr/sbin/apachectl -DFOREGROUND
