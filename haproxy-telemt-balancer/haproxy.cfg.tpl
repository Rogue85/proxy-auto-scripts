global
    log stdout format raw local0
    maxconn 100000
    nbthread 2
    tune.maxaccept 1000

defaults
    log global
    mode tcp
    option tcplog
    option clitcpka
    option srvtcpka
    timeout connect 5s
    timeout client 30m
    timeout server 30m
    timeout check 5s

frontend tcp_in
    bind *:${LISTEN_PORT} reuseport
    maxconn 80000
    default_backend telemt_nodes

backend telemt_nodes
    balance roundrobin
    stick-table type ip size 200k expire 30m
    stick on src
    default-server inter 5s rise 2 fall 3${SEND_PROXY_V2_SUFFIX}
${TELEMT_BACKEND_SERVERS}
