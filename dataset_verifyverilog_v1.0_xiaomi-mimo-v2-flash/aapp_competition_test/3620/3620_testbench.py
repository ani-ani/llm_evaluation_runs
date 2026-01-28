import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# Test constants
NODES_MAX = 16
EDGES_MAX = 48
CLK_NS = 10
MAX_CYCLES = 1000

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_graph_coloring(dut):
    # Setup clock and reset
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(2): await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test cases (scaled to 16 nodes, k≤256)
    # Case 1: Triangle (3 nodes, 3 edges) - should be 0 for k=2
    # Scaled: nodes 0,1,2 connected
    test_cases = [
        {"nodes": [[1,2],[0,2],[1,0]], "edges": [[0,1],[1,2],[2,0]], "k": 2, "P": 10000, "expected": 0},
        {"nodes": [[1,2],[0,2],[1,0]], "edges": [[0,1],[1,2],[2,0]], "k": 4, "P": 13, "expected": 11},
    ]
    
    passed = failed = 0
    for case_idx, case in enumerate(test_cases):
        cocotb.log.info(f"Test case {case_idx+1}: Triangle with k={case['k']}, P={case['P']}")
        
        try:
            # Write adjacency matrix (row per node, bits for neighbors)
            if has_signal(dut, 'adjacency'):
                for node in range(NODES_MAX):
                    if node < len(case['nodes']):
                        row_val = 0
                        for neighbor in case['nodes'][node]:
                            if neighbor < NODES_MAX:
                                row_val |= (1 << neighbor)
                        dut.adjacency[node].value = clamp_to_width(row_val, NODES_MAX)
                    else:
                        dut.adjacency[node].value = 0
            
            # Write edges list (if separate port)
            if has_signal(dut, 'edges'):
                for edge_idx in range(EDGES_MAX):
                    if edge_idx < len(case['edges']):
                        edge = case['edges'][edge_idx]
                        # Pack two 4-bit values into 8-bit
                        packed = (edge[0] & 0xF) | ((edge[1] & 0xF) << 4)
                        dut.edges[edge_idx].value = packed
                    else:
                        dut.edges[edge_idx].value = 0
            
            # Write k and P
            if has_signal(dut, 'k_in'): dut.k_in.value = clamp_to_width(case['k'], 8)
            if has_signal(dut, 'p_in'): dut.p_in.value = clamp_to_width(case['P'], 32)
            
            # Start computation
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done with timeout
                done = False
                for _ in range(MAX_CYCLES):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        done = True
                        break
                
                if not done:
                    raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                
                result = int(dut.result.value) % case['P']
            else:
                await Timer(100, units='ns')
                result = int(dut.result.value) if is_value_defined(dut.result.value) else 0
            
            if result != case['expected']:
                raise TestFailure(f"Expected {case['expected']}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: {result} matches expected")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed, {passed} passed")
