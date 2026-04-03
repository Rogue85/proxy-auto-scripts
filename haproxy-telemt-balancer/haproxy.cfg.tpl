global
    log stdout format raw local0
    maxconn 10000

defaults
    log global
    mode tcp
    option tcplog
    option clitcpka
    option srvtcpka
    timeout connect 5s
    timeout client 2h
    timeout server 2h
    timeout check 5s

frontend tcp_in
    bind *:${LISTEN_PORT}
    maxconn 8000
    default_backend telemt_nodes

backend telemt_nodes
    balance roundrobin
    default-server inter 5s rise 2 fall 3${SEND_PROXY_V2_SUFFIX}
${TELEMT_BACKEND_SERVERS}
