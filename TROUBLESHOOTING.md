# Troubleshooting

## n8n cannot connect to Ollama

If a workflow node reports “The service refused the connection,” check that
Ollama is running and reachable from the n8n container. On Linux, Docker may
not resolve `host.docker.internal` automatically, and Ollama may listen only
on the host's loopback interface.

### 1. Add the host name to Docker Compose

In `docker-compose.yml`, add `extra_hosts` under the `n8n` service:

```yaml
services:
  n8n:
    extra_hosts:
      - "host.docker.internal:host-gateway"
```

Keep the rest of the service configuration as-is. The workflow's Ollama
requests use `http://host.docker.internal:11434`.

### 2. Make Ollama reachable from Docker

For an Ollama installation managed by systemd, create an override:

```bash
sudo systemctl edit ollama
```

Add:

```ini
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
```

Save and close the editor, then restart Ollama:

```bash
sudo systemctl restart ollama
```

Binding Ollama to `0.0.0.0` exposes port 11434 on all host interfaces. Restrict
access to that port with your firewall if the machine is on a network you do
not fully trust.

### 3. Recreate n8n

From the project directory, apply the Compose change:

```bash
docker compose up -d
```

### 4. Verify the connection

Check Ollama from the host:

```bash
curl http://127.0.0.1:11434/api/tags
```

Check that the n8n container can resolve the hostname and reach Ollama:

```bash
docker exec n8n_specialists node -e \
  "fetch('http://host.docker.internal:11434/api/tags').then(async r => { console.log(r.status); console.log(await r.text()); }).catch(e => { console.error(e); process.exit(1); })"
```

The second command should print HTTP status `200` and the installed model list.
If it fails, check `docker compose logs n8n` and confirm Ollama is active with
`systemctl status ollama`.

### If the container still times out

If Ollama is listening on `0.0.0.0:11434` and the hostname resolves, but the
container request times out, a host firewall may be blocking traffic from the
Docker bridge. Check whether UFW is active:

```bash
sudo ufw status verbose
```

For the default Docker Compose bridge network, get its network ID and subnet:

```bash
network_name="$(docker inspect n8n_specialists --format '{{range $name, $network := .NetworkSettings.Networks}}{{$name}}{{end}}')"
docker network inspect "$network_name" --format 'ID={{.Id}} Subnet={{(index .IPAM.Config 0).Subnet}}'
```

The bridge interface is usually `br-` followed by the first 12 characters of
the network ID. If UFW is active, allow Ollama traffic only from that bridge
and Compose subnet. Replace the interface and subnet below with the values
from the previous command:

```bash
sudo ufw allow in on br-<first-12-characters-of-network-id> \
  from <compose-subnet> to any port 11434 proto tcp
```

Then repeat the container connection check above. To remove this rule later,
run `sudo ufw delete allow` with the same interface, subnet, port, and protocol
arguments. If UFW is inactive or another firewall is in use, add an equivalent
inbound rule for TCP port 11434 from the Compose subnet on its Docker bridge.

## Deep Debugger request times out

If the **Deep Debugger (DeepSeek R1 7B)** node reports that the connection was
aborted, check `.n8n/n8n.log` for `timeout of 300000ms exceeded`. This indicates
that n8n waited five minutes for Ollama to finish the request; it does not
necessarily mean Ollama was offline. DeepSeek R1 can spend a long time generating
reasoning, especially on CPU or under memory pressure.

The tracked workflow now disables extended thinking for the debugger and limits
its response to 256 tokens. If this workflow was already imported into n8n,
update the existing **Deep Debugger (DeepSeek R1 7B)** HTTP Request node's body
to match the node definition in [workflow.json](./workflows/workflow.json);
editing the tracked file does not automatically update an existing n8n
workflow. Then retry the task. You can also check whether inference is still
running with:

```bash
ollama ps
```
