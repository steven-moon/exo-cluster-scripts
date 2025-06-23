#!/usr/bin/env python3
"""
ExoManager MCP Client for Cursor IDE
Connects to the ExoManager MCP server and displays real-time debug information.
"""

import socket
import json
import threading
import time
import sys
from datetime import datetime
from typing import Dict, Any, Optional

class ExoMCPClient:
    def __init__(self, host: str = "localhost", port: int = 52417):
        self.host = host
        self.port = port
        self.socket: Optional[socket.socket] = None
        self.connected = False
        self.running = False
        
        # Message counters for statistics
        self.message_count = 0
        self.error_count = 0
        self.warning_count = 0
        self.info_count = 0
        
        # Performance tracking
        self.last_performance_update = time.time()
        self.performance_history = []
        
    def connect(self) -> bool:
        """Connect to the ExoManager MCP server."""
        try:
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.socket.connect((self.host, self.port))
            self.connected = True
            self.running = True
            
            print(f"🎉 Connected to ExoManager MCP Server at {self.host}:{self.port}")
            print("📡 Receiving real-time debug information...")
            print("=" * 60)
            
            return True
            
        except Exception as e:
            print(f"❌ Failed to connect to MCP server: {e}")
            return False
    
    def disconnect(self):
        """Disconnect from the MCP server."""
        self.running = False
        if self.socket:
            self.socket.close()
        self.connected = False
        print("\n🔌 Disconnected from MCP server")
    
    def receive_messages(self):
        """Receive and process messages from the MCP server."""
        buffer = b""
        
        while self.running and self.connected:
            try:
                data = self.socket.recv(4096)
                if not data:
                    break
                
                buffer += data
                
                # Try to parse complete JSON messages
                while b'\n' in buffer:
                    line, buffer = buffer.split(b'\n', 1)
                    if line.strip():
                        self.process_message(line.decode('utf-8'))
                        
            except Exception as e:
                if self.running:
                    print(f"❌ Error receiving message: {e}")
                break
    
    def process_message(self, message_str: str):
        """Process a single MCP message."""
        try:
            message = json.loads(message_str)
            self.message_count += 1
            
            message_type = message.get('type', 'unknown')
            timestamp = message.get('timestamp', '')
            source = message.get('source', 'unknown')
            data = message.get('data', {})
            
            # Format timestamp
            if timestamp:
                try:
                    dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
                    time_str = dt.strftime('%H:%M:%S')
                except:
                    time_str = timestamp
            else:
                time_str = datetime.now().strftime('%H:%M:%S')
            
            # Process different message types
            if message_type == 'welcome':
                self.handle_welcome(data, time_str)
            elif message_type == 'log_entry':
                self.handle_log_entry(data, time_str, source)
            elif message_type == 'performance_metrics':
                self.handle_performance_metrics(data, time_str)
            elif message_type == 'service_status':
                self.handle_service_status(data, time_str)
            elif message_type == 'network_discovery':
                self.handle_network_discovery(data, time_str)
            elif message_type == 'debug_message':
                self.handle_debug_message(data, time_str, source)
            else:
                print(f"📨 [{time_str}] Unknown message type: {message_type}")
                
        except json.JSONDecodeError as e:
            print(f"❌ Failed to parse JSON message: {e}")
            print(f"   Raw message: {message_str[:100]}...")
        except Exception as e:
            print(f"❌ Error processing message: {e}")
    
    def handle_welcome(self, data: Dict[str, Any], time_str: str):
        """Handle welcome message from server."""
        server = data.get('server', 'Unknown')
        version = data.get('version', 'Unknown')
        capabilities = data.get('capabilities', [])
        
        print(f"🎉 [{time_str}] Connected to {server} v{version}")
        print(f"   📋 Capabilities: {', '.join(capabilities)}")
        print("-" * 60)
    
    def handle_log_entry(self, data: Dict[str, Any], time_str: str, source: str):
        """Handle log entry message."""
        level = data.get('level', 'UNKNOWN').upper()
        message = data.get('message', '')
        is_error = data.get('isError', False)
        
        # Update counters
        if is_error or level == 'ERROR':
            self.error_count += 1
            prefix = "❌"
        elif level == 'WARNING':
            self.warning_count += 1
            prefix = "⚠️"
        else:
            self.info_count += 1
            prefix = "ℹ️"
        
        print(f"{prefix} [{time_str}] [{level}] {message}")
    
    def handle_performance_metrics(self, data: Dict[str, Any], time_str: str):
        """Handle performance metrics message."""
        cpu = data.get('cpu', 0.0)
        memory = data.get('memory', 0.0)
        disk = data.get('disk', 0.0)
        gpu = data.get('gpu', 0.0)
        network_status = data.get('network_status', 'Unknown')
        web_accessible = data.get('web_interface_accessible', False)
        api_accessible = data.get('api_endpoint_accessible', False)
        
        # Store performance data
        self.performance_history.append({
            'timestamp': time.time(),
            'cpu': cpu,
            'memory': memory,
            'disk': disk,
            'gpu': gpu
        })
        
        # Keep only last 100 entries
        if len(self.performance_history) > 100:
            self.performance_history.pop(0)
        
        # Create status indicators
        web_status = "🟢" if web_accessible else "🔴"
        api_status = "🟢" if api_accessible else "🔴"
        
        print(f"📊 [{time_str}] CPU: {cpu:.1f}% | Memory: {memory:.1f}% | Disk: {disk:.1f}% | GPU: {gpu:.1f}%")
        print(f"   🌐 Network: {network_status} | Web: {web_status} | API: {api_status}")
    
    def handle_service_status(self, data: Dict[str, Any], time_str: str):
        """Handle service status message."""
        is_installed = data.get('is_installed', False)
        is_running = data.get('is_running', False)
        is_installing = data.get('is_installing', False)
        is_uninstalling = data.get('is_uninstalling', False)
        last_error = data.get('last_error', '')
        progress = data.get('installation_progress', '')
        
        if is_installing:
            status = "🔄 Installing"
            if progress:
                status += f" - {progress}"
        elif is_uninstalling:
            status = "🔄 Uninstalling"
        elif is_installed:
            status = "🟢 Running" if is_running else "🔴 Stopped"
        else:
            status = "⚪ Not Installed"
        
        print(f"🔧 [{time_str}] Service: {status}")
        
        if last_error:
            print(f"   ❌ Error: {last_error}")
    
    def handle_network_discovery(self, data: Dict[str, Any], time_str: str):
        """Handle network discovery message."""
        is_discovering = data.get('is_discovering', False)
        node_count = data.get('discovered_nodes_count', 0)
        last_error = data.get('last_error', '')
        nodes = data.get('nodes', [])
        
        status = "🔍 Scanning" if is_discovering else "💤 Idle"
        print(f"🌐 [{time_str}] Network Discovery: {status} | Nodes: {node_count}")
        
        if last_error:
            print(f"   ❌ Error: {last_error}")
        
        # Show recent nodes
        if nodes:
            recent_nodes = nodes[-3:]  # Show last 3 nodes
            for node in recent_nodes:
                name = node.get('name', 'Unknown')
                address = node.get('address', 'Unknown')
                online = "🟢" if node.get('is_online', False) else "🔴"
                print(f"   {online} {name} ({address})")
    
    def handle_debug_message(self, data: Dict[str, Any], time_str: str, source: str):
        """Handle debug message."""
        level = data.get('level', 'DEBUG').upper()
        message = data.get('message', '')
        
        if level == 'ERROR':
            prefix = "❌"
        elif level == 'WARNING':
            prefix = "⚠️"
        else:
            prefix = "🔍"
        
        print(f"{prefix} [{time_str}] [{source}] {message}")
    
    def print_statistics(self):
        """Print connection statistics."""
        print("\n" + "=" * 60)
        print("📈 STATISTICS")
        print("=" * 60)
        print(f"Total Messages: {self.message_count}")
        print(f"Errors: {self.error_count}")
        print(f"Warnings: {self.warning_count}")
        print(f"Info: {self.info_count}")
        
        if self.performance_history:
            avg_cpu = sum(p['cpu'] for p in self.performance_history) / len(self.performance_history)
            avg_memory = sum(p['memory'] for p in self.performance_history) / len(self.performance_history)
            print(f"Average CPU: {avg_cpu:.1f}%")
            print(f"Average Memory: {avg_memory:.1f}%")
    
    def run(self):
        """Main run loop."""
        if not self.connect():
            return
        
        # Start message receiving thread
        receive_thread = threading.Thread(target=self.receive_messages, daemon=True)
        receive_thread.start()
        
        try:
            # Main loop - handle user input
            while self.running:
                try:
                    # Check for user input (non-blocking)
                    if sys.platform == "win32":
                        import msvcrt
                        if msvcrt.kbhit():
                            key = msvcrt.getch()
                            if key == b'q':
                                break
                    else:
                        # Unix-like systems
                        import select
                        if select.select([sys.stdin], [], [], 0.1)[0]:
                            line = sys.stdin.readline()
                            if line.strip().lower() == 'q':
                                break
                    
                    time.sleep(0.1)
                    
                except KeyboardInterrupt:
                    break
                except Exception as e:
                    print(f"❌ Error in main loop: {e}")
                    break
                    
        finally:
            self.print_statistics()
            self.disconnect()

def main():
    """Main entry point."""
    import argparse
    
    parser = argparse.ArgumentParser(description='ExoManager MCP Client')
    parser.add_argument('--host', default='localhost', help='MCP server host (default: localhost)')
    parser.add_argument('--port', type=int, default=52417, help='MCP server port (default: 52417)')
    
    args = parser.parse_args()
    
    print("🚀 ExoManager MCP Client for Cursor IDE")
    print("=" * 60)
    print("This client connects to the ExoManager MCP server and displays")
    print("real-time debug information, logs, and performance metrics.")
    print("=" * 60)
    print("Press 'q' and Enter to quit")
    print("=" * 60)
    
    client = ExoMCPClient(args.host, args.port)
    client.run()

if __name__ == "__main__":
    main() 