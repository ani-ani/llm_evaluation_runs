import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH, MAX_NODES, CLK_NS, MAX_CYCLES = 8, 16, 10, 256

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def pack_4bit_pairs(pairs, num_pairs):
    """Pack list of (a,b) pairs into 32-bit value (4 bits each)"""
    result = 0
    for i, (a, b) in enumerate(pairs[:num_pairs]):
        result |= ((a & 0xF) << (i*8)) | ((b & 0xF) << (i*8 + 4))
    return result

def compute_expected_diameter(num_computers, cables):
    """Compute expected result in Python for verification"""
    if num_computers <= 1:
        return 0
    if not cables:
        return num_computers - 1
    
    # Build adjacency list
    adj = [[] for _ in range(num_computers)]
    for a, b in cables:
        adj[a].append(b)
        adj[b].append(a)
    
    # Find components and their diameters
    visited = [False] * num_computers
    components = []
    
    for start in range(num_computers):
        if not visited[start]:
            # BFS to get all nodes in component
            comp_nodes = [start]
            queue = [start]
            visited[start] = True
            while queue:
                u = queue.pop(0)
                for v in adj[u]:
                    if not visited[v]:
                        visited[v] = True
                        comp_nodes.append(v)
                        queue.append(v)
            
            # Find diameter of this component
            max_diam = 0
            if len(comp_nodes) == 1:
                max_diam = 0
            else:
                # BFS from each node to find max distance
                for src in comp_nodes:
                    dist = [-1] * num_computers
                    dist[src] = 0
                    q = [src]
                    while q:
                        u = q.pop(0)
                        for v in adj[u]:
                            if dist[v] == -1:
                                dist[v] = dist[u] + 1
                                q.append(v)
                    max_diam = max(max_diam, max(dist[n] for n in comp_nodes))
            components.append(max_diam)
    
    if not components:
        return 0
    if len(components) == 1:
        return components[0]
    
    # Connect components in star topology
    # Diameter = max(component_diameter, 1 + ceil(log2(num_components)))
    # But with star topology: max is max(diameter) + 2 (through center)
    # Simplified: max(diameter) + 2 for star connection
    # Actually: if we connect centers in star, max path is max(diameter) + 2
    max_comp_diam = max(components)
    num_comps = len(components)
    if num_comps == 2:
        return max_comp_diam + 1
    elif num_comps == 3:
        return max_comp_diam + 2
    elif num_comps >= 4:
        return max_comp_diam + 3
    return max_comp_diam

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_network_diameter(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (num_computers, cables_list, expected_diameter, description)
    test_cases = [
        (2, [], 1, "2 nodes, no cables"),
        (1, [], 0, "1 node"),
        (4, [(0,1), (2,3)], 3, "2 trees of 2 nodes"),
        (6, [(0,1), (0,2), (3,4), (3,5)], 3, "2 trees of 3 nodes"),
        (11, [(0,1),(0,3),(0,4),(1,2),(5,4),(6,4),(7,8),(7,9),(7,10)], 4, "complex test"),
        (5, [(0,1),(1,2),(3,4)], 3, "3 components"),
        (8, [(0,1),(0,2),(1,3),(4,5),(6,7)], 4, "mixed components"),
    ]
    
    passed = failed = 0
    
    for i, (num_comps, cables, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - {num_comps} computers, {len(cables)} cables")
        try:
            # Calculate expected
            expected = compute_expected_diameter(num_comps, cables)
            if expected != exp:
                raise TestFailure(f"Expected calculation error: {expected} vs {exp}")
            
            # Prepare inputs
            cable_a_list = [a for a, b in cables]
            cable_b_list = [b for a, b in cables]
            packed_a = pack_4bit_pairs(list(zip(cable_a_list, cable_b_list)), len(cables))
            packed_b = pack_4bit_pairs(list(zip(cable_b_list, cable_a_list)), len(cables))
            
            # Set inputs
            dut.num_computers.value = num_comps
            dut.num_cables.value = len(cables)
            dut.cable_a.value = packed_a
            dut.cable_b.value = packed_b
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: Result {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
