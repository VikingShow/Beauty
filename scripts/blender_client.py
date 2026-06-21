"""Direct TCP client for Blender MCP addon."""
import socket
import json
import sys

HOST = "localhost"
PORT = 9876

def send_command(sock, cmd_type, params=None):
    """Send a command to Blender and return the result."""
    command = {"type": cmd_type, "params": params or {}}
    sock.sendall(json.dumps(command).encode('utf-8'))
    sock.settimeout(30.0)
    chunks = []
    while True:
        try:
            chunk = sock.recv(8192)
            if not chunk:
                break
            chunks.append(chunk)
            try:
                data = b''.join(chunks)
                json.loads(data.decode('utf-8'))
                break
            except json.JSONDecodeError:
                continue
        except socket.timeout:
            break
    data = b''.join(chunks)
    response = json.loads(data.decode('utf-8'))
    if response.get("status") == "error":
        raise Exception(response.get("message", "Unknown error"))
    return response.get("result", response)

def main():
    args = sys.argv[1:]
    if not args:
        print("Usage: blender_client.py <command> [json_params]")
        print("  Commands: get_scene_info, get_object_info, execute_blender_code, etc.")
        print("  Or pass raw JSON command: blender_client.py '{\"type\":\"...\",\"params\":{}}'")
        sys.exit(1)

    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(10.0)

    try:
        sock.connect((HOST, PORT))
        if len(args) == 1 and args[0].startswith('{'):
            command = json.loads(args[0])
            result = send_command(sock, command["type"], command.get("params", {}))
        else:
            cmd = args[0]
            params = json.loads(args[1]) if len(args) > 1 else {}
            result = send_command(sock, cmd, params)

        print(json.dumps(result, indent=2, ensure_ascii=False))
    finally:
        sock.close()

if __name__ == "__main__":
    main()
