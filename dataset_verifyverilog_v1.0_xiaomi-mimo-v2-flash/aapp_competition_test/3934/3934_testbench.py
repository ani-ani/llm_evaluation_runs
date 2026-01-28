import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=200):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_tree_degree_check(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (n, edges_list, expected_result, description)
    # edges_list: list of (u, v) tuples (1-indexed)
    test_cases = [
        (2, [(1, 2)], 1, "2 nodes, YES"),
        (3, [(1, 2), (2, 3)], 0, "3 nodes path, NO"),
        (5, [(1, 2), (1, 3), (1, 4), (2, 5)], 0, "Example 3, NO"),
        (6, [(1, 2), (1, 3), (1, 4), (2, 5), (2, 6)], 1, "Example 4, YES"),
        (4, [(2, 4), (2, 3), (2, 1)], 1, "4 nodes star, YES"),
        (5, [(5, 1), (5, 2), (5, 3), (5, 4)], 1, "5 nodes star, YES"),
        (3, [(1, 2), (1, 3)], 0, "3 nodes star, NO"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, edges, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        try:
            # Set n (8-bit)
            dut.n.value = clamp_to_width(n, 8)
            
            # Reset all edges and edge_valid flags
            max_edges = 20  # from spec
            for j in range(max_edges):
                getattr(dut, f'edge_u_{j}').value = 0
                getattr(dut, f'edge_v_{j}').value = 0
                getattr(dut, f'edge_valid_{j}').value = 0
            
            # Set edges
            for j, (u, v) in enumerate(edges):
                if j >= max_edges:
                    raise TestFailure(f"Too many edges for test {desc}")
                getattr(dut, f'edge_u_{j}').value = clamp_to_width(u, 5)
                getattr(dut, f'edge_v_{j}').value = clamp_to_width(v, 5)
                getattr(dut, f'edge_valid_{j}').value = 1
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: {desc}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
        
        # Reset between tests
        await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    
    cocotb.log.info(f"All {passed} tests passed")
