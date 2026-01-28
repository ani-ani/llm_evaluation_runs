import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import re

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# TESTBENCH HELPER FUNCTIONS
# ============================================================================

def pack_graph(n, edges):
    """Pack graph adjacency matrix into 64-bit integer."""
    graph_packed = 0
    for i in range(n):
        for j in range(n):
            if (i, j) in edges:
                graph_packed |= (1 << (i * 8 + j))
    return graph_packed

def parse_input(input_str):
    """Parse problem input and return n, file_names, edges."""
    lines = input_str.strip().split('\n')
    n = int(lines[0])
    file_names = lines[1].split()
    
    edges = set()
    line_idx = 2
    
    for i in range(n):
        parts = lines[line_idx].split()
        file_name = parts[0]
        k = int(parts[1])
        line_idx += 1
        
        src_idx = file_names.index(file_name)
        
        for _ in range(k):
            import_line = lines[line_idx].strip()
            line_idx += 1
            # Remove "import " prefix
            imported = import_line[7:].split(', ')
            for imp in imported:
                dst_idx = file_names.index(imp)
                edges.add((src_idx, dst_idx))
    
    return n, file_names, edges

def find_shortest_cycle_py(n, edges):
    """Find shortest cycle in Python for verification."""
    from collections import deque
    
    # Build adjacency list
    adj = [[] for _ in range(n)]
    for src, dst in edges:
        adj[src].append(dst)
    
    min_cycle = None
    min_len = float('inf')
    
    for start in range(n):
        # BFS from start
        dist = [-1] * n
        parent = [-1] * n
        dist[start] = 0
        queue = deque([start])
        
        while queue:
            node = queue.popleft()
            for neighbor in adj[node]:
                if neighbor == start and dist[node] > 0:
                    # Found cycle
                    cycle_len = dist[node] + 1
                    if cycle_len < min_len:
                        min_len = cycle_len
                        # Reconstruct cycle
                        cycle = [start]
                        curr = node
                        while curr != start:
                            cycle.append(curr)
                            curr = parent[curr]
                        min_cycle = cycle
                elif dist[neighbor] == -1:
                    dist[neighbor] = dist[node] + 1
                    parent[neighbor] = node
                    queue.append(neighbor)
    
    return min_cycle

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_shortest_cycle(dut):
    """Main test function."""
    
    # Configuration
    CLK_PERIOD_NS = 10
    MAX_CYCLES = 1000
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases from problem
    test_inputs = [
        "4\na b c d\na 1\nimport d, b, c\nb 2\nimport d\nimport c\nc 1\nimport c\nd 0\n",
        "5\nclassa classb myfilec execd libe\nclassa 2\nimport classb\nimport myfilec, libe\nclassb 1\nimport execd\nmyfilec 1\nimport libe\nexecd 1\nimport libe\nlibe 0\n",
        "5\nclassa classb myfilec execd libe\nclassa 2\nimport classb\nimport myfilec, libe\nclassb 1\nimport execd\nmyfilec 1\nimport libe\nexecd 1\nimport libe, classa\nlibe 0\n"
    ]
    
    expected_outputs = [
        "c",
        "SHIP IT",
        "classa classb execd"
    ]
    
    for test_idx, (input_str, expected) in enumerate(zip(test_inputs, expected_outputs)):
        dut._log.info(f"Running test case {test_idx + 1}")
        
        # Parse input
        n, file_names, edges = parse_input(input_str)
        
        # Scale down: if n > 8, take first 8 files
        if n > 8:
            n = 8
            # Filter edges to only include first 8 files
            edges = {(src, dst) for src, dst in edges if src < 8 and dst < 8}
        
        # Pack graph
        graph_packed = pack_graph(n, edges)
        
        # Verify with Python
        py_cycle = find_shortest_cycle_py(n, edges)
        
        if py_cycle is None:
            py_expected = "SHIP IT"
        else:
            py_expected = " ".join([file_names[i] for i in py_cycle])
        
        # Drive DUT
        dut.n.value = n
        dut.graph.value = graph_packed
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        cycles = 0
        while not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > MAX_CYCLES:
                raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
        
        # Read results
        if not is_value_defined(dut.cycle_length.value):
            raise TestFailure("Cycle length is undefined")
        
        cycle_length = int(dut.cycle_length.value)
        
        if cycle_length == 0:
            result = "SHIP IT"
        else:
            # Read cycle indices from packed cycle output
            cycle_indices = []
            for i in range(cycle_length):
                # Extract 3-bit index from packed cycle
                index = (int(dut.cycle.value) >> (3 * i)) & 0x7
                cycle_indices.append(index)
            
            # Convert indices to file names
            result = " ".join([file_names[idx] for idx in cycle_indices])
        
        # Verify
        if result != expected:
            dut._log.error(f"Test {test_idx + 1} FAILED")
            dut._log.error(f"  Expected: {expected}")
            dut._log.error(f"  Got:      {result}")
            dut._log.error(f"  Python:   {py_expected}")
            raise TestFailure(f"Test {test_idx + 1} failed")
        
        dut._log.info(f"Test {test_idx + 1} PASSED: {result}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info("All tests passed")