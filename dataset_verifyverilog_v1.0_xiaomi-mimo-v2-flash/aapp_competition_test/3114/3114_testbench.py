import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
MAX_N = 8
MAX_M = 28
DATA_WIDTH = 4
CLK_NS = 10
MAX_CYCLES = 2000

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
    max_val = (1 << bits) - 1
    return max(0, min(max_val, v))

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_edges(dut, edges_u, edges_v, M):
    """Write edge lists to input ports"""
    for i in range(M):
        u = clamp_to_width(edges_u[i], DATA_WIDTH)
        v = clamp_to_width(edges_v[i], DATA_WIDTH)
        if has_signal(dut, f'edge_u_{i}'):
            getattr(dut, f'edge_u_{i}').value = u
            getattr(dut, f'edge_v_{i}').value = v
        else:
            # Packed array case
            dut.edge_u[i].value = u
            dut.edge_v[i].value = v

async def read_output(dut, M):
    """Read oriented edges from output ports"""
    out_u = []
    out_v = []
    for i in range(M):
        if has_signal(dut, f'out_u_{i}'):
            u = int(getattr(dut, f'out_u_{i}').value)
            v = int(getattr(dut, f'out_v_{i}').value)
        else:
            u = int(dut.out_u[i].value)
            v = int(dut.out_v[i].value)
        out_u.append(u)
        out_v.append(v)
    return out_u, out_v

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_graph_orientation(dut):
    """Test graph orientation module"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (N, M, edges_u, edges_v, expected_result, description)
    test_cases = [
        (3, 3, [1,2,1], [2,3,3], 1, "Triangle - YES"),
        (4, 3, [1,1,1], [2,3,4], 0, "Star graph - NO (has bridges)"),
        (4, 5, [1,2,4,1,2], [2,3,3,4,4], 1, "K4 minus one edge - YES"),
        (1, 0, [], [], 1, "Single node - YES"),
        (2, 1, [1], [2], 1, "Two nodes - YES"),
        (3, 2, [1,2], [2,3], 0, "Path graph - NO (has bridges)"),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (N, M, edges_u, edges_v, expected_result, desc) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {test_idx+1}: {desc}")
        cocotb.log.info(f"  Input: N={N}, M={M}, edges={list(zip(edges_u, edges_v))}")
        
        try:
            # Write inputs
            dut.N.value = clamp_to_width(N, 4)
            dut.M.value = clamp_to_width(M, 6)
            
            # Write edge arrays
            for i in range(M):
                u = clamp_to_width(edges_u[i], DATA_WIDTH)
                v = clamp_to_width(edges_v[i], DATA_WIDTH)
                if has_signal(dut, f'edge_u_{i}'):
                    getattr(dut, f'edge_u_{i}').value = u
                    getattr(dut, f'edge_v_{i}').value = v
                else:
                    dut.edge_u[i].value = u
                    dut.edge_v[i].value = v
            
            # Clear unused edges
            for i in range(M, MAX_M):
                if has_signal(dut, f'edge_u_{i}'):
                    getattr(dut, f'edge_u_{i}').value = 0
                    getattr(dut, f'edge_v_{i}').value = 0
                else:
                    dut.edge_u[i].value = 0
                    dut.edge_v[i].value = 0
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for completion
            await wait_for_done(dut, MAX_CYCLES)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            cocotb.log.info(f"  Result: {result}, Expected: {expected_result}")
            
            # Verify result
            if result != expected_result:
                raise TestFailure(f"Result mismatch: got {result}, expected {expected_result}")
            
            # If YES, verify output edges are valid
            if result == 1 and M > 0:
                out_u, out_v = await read_output(dut, M)
                cocotb.log.info(f"  Output edges: {list(zip(out_u, out_v))}")
                
                # Check that all original edges appear exactly once
                original_edges = set()
                for u, v in zip(edges_u, edges_v):
                    original_edges.add((min(u,v), max(u,v)))
                
                oriented_edges = set()
                for i in range(M):
                    u = out_u[i]
                    v = out_v[i]
                    if u == 0 or v == 0 or u > N or v > N or u == v:
                        raise TestFailure(f"Invalid edge: ({u},{v})")
                    # Check orientation uses valid nodes
                    oriented_edges.add((u, v))
                    
                    # Original undirected edge must be preserved
                    undirected = (min(u,v), max(u,v))
                    if undirected not in original_edges:
                        raise TestFailure(f"Oriented edge {u}->{v} doesn't match any original edge")
                
                # Check no duplicate orientations
                if len(oriented_edges) != M:
                    raise TestFailure(f"Duplicate or missing edges: got {len(oriented_edges)} distinct, expected {M}")
            
            passed += 1
            cocotb.log.info(f"  PASS")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset between tests
        await reset_dut(dut)
        await Timer(100, units='ns')
    
    cocotb.log.info(f"\n=== Final Results: {passed} passed, {failed} failed ===")
    if failed:
        raise TestFailure(f"{failed} test(s) failed")
