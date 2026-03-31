#!/bin/bash

# Colors for better readability on the terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}   Proxmox LXC & Docker NPM/Axios Scanner       ${NC}"
echo -e "${BLUE}==================================================${NC}"

# Get all running LXC containers (status 'running')
running_lxcs=$(pct list | awk 'NR>1 && $2=="running" {print $1}')

if [ -z "$running_lxcs" ]; then
    echo -e "${YELLOW}[!] No running LXC containers found.${NC}"
    exit 0
fi

for vmid in $running_lxcs; do
    hostname=$(pct exec $vmid -- hostname 2>/dev/null)
    echo -e "\n${BLUE}[LXC $vmid - $hostname]${NC}"
    
    # --------------------------------------------------
    # 1. Native Scan in the LXC
    # --------------------------------------------------
    # Force 'sh' to execute the command so built-ins work
    has_npm=$(pct exec $vmid -- sh -c "command -v npm" 2>/dev/null)
    
    if [ -n "$has_npm" ]; then
        echo -e "  ${GREEN}✓${NC} NPM is natively installed in the LXC."
        
        # Check global Axios
        global_axios=$(pct exec $vmid -- sh -c "npm list -g axios --depth=0 2>/dev/null | grep axios")
        if [ -n "$global_axios" ]; then
            echo -e "    -> ${GREEN}Global Axios found:${NC} $global_axios"
        else
            echo "    -> No global Axios found."
        fi
        
        # Find active Node processes
        node_pids=$(pct exec $vmid -- pgrep node 2>/dev/null)
        if [ -n "$node_pids" ]; then
            echo -e "    -> ${YELLOW}Running Node processes found. Checking project directories...${NC}"
            for pid in $node_pids; do
                cwd=$(pct exec $vmid -- readlink /proc/$pid/cwd 2>/dev/null)
                if [ -n "$cwd" ]; then
                    axios_version=$(pct exec $vmid -- sh -c "cd $cwd 2>/dev/null && npm list axios --depth=0 2>/dev/null | grep axios")
                    if [ -n "$axios_version" ]; then
                        echo -e "       - Path: $cwd -> ${GREEN}Axios Version:${NC} $axios_version"
                    else
                        echo -e "       - Path: $cwd (Axios not found or not an npm project)"
                    fi
                fi
            done
        fi
    else
        echo "  [-] NPM is not natively installed."
    fi

    # --------------------------------------------------
    # 2. Scan for Docker inside the LXC
    # --------------------------------------------------
    has_docker=$(pct exec $vmid -- sh -c "command -v docker" 2>/dev/null)
    
    if [ -n "$has_docker" ]; then
        echo -e "  ${YELLOW}ℹ${NC} Docker is installed. Checking running containers..."
        
        # Attempt to query running containers
        containers=$(pct exec $vmid -- docker ps --format "{{.ID}}|{{.Names}}" 2>/dev/null)
        exit_code=$?
        
        if [ $exit_code -eq 0 ] && [ -n "$containers" ]; then
            echo "$containers" | while IFS='|' read -r container_id container_name; do
                echo -e "    -> Container: ${BLUE}$container_name${NC} ($container_id)"
                
                # Check if NPM is in the container
                npm_in_docker=$(pct exec $vmid -- docker exec $container_id sh -c "command -v npm" 2>/dev/null)
                if [ -n "$npm_in_docker" ]; then
                    docker_axios=$(pct exec $vmid -- docker exec $container_id sh -c "npm list axios --depth=0 2>/dev/null | grep axios")
                    if [ -n "$docker_axios" ]; then
                        echo -e "       -> ${GREEN}Axios found:${NC} $docker_axios"
                    else
                        echo "       -> NPM present, but Axios not found in dependencies."
                    fi
                else
                    # Fallback: Search directly in the file system of the Docker container for Axios
                    axios_dir=$(pct exec $vmid -- docker exec $container_id find / -type d -name "axios" -path "*/node_modules/axios" 2>/dev/null | head -n 1)
                    if [ -n "$axios_dir" ]; then
                        axios_v=$(pct exec $vmid -- docker exec $container_id sh -c "cat $axios_dir/package.json 2>/dev/null" | grep '"version":' | awk -F'"' '{print $4}')
                        if [ -n "$axios_v" ]; then
                            echo -e "       -> ${GREEN}Axios found${NC} (via path): Version $axios_v"
                        else
                            echo -e "       -> ${GREEN}Axios found${NC} (via path), version could not be determined."
                        fi
                    else
                        echo "       -> Neither NPM nor Axios modules found in the container."
                    fi
                fi
            done
        elif [ $exit_code -eq 0 ]; then
            echo "    -> No running Docker containers found."
        else
            echo -e "    -> ${RED}Error:${NC} Docker daemon is not responding (permission issue or daemon not running)."
        fi
    else
        echo "  [-] Docker is not installed."
    fi
done

echo -e "\n${BLUE}==================================================${NC}"
echo "Scan complete."
