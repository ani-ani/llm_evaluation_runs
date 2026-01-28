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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Write edges to array ports
async def write_edges(dut, edges, num_edges):
    for i in range(16):
        if i < num_edges:
            # Assuming edge_A[i] and edge_B[i] are individual ports
            a, b = edges[i]
            dut.edge_A[i].value = a
            dut.edge_B[i].value = b
        else:
            dut.edge_A[i].value = 0
            dut.edge_B[i].value = 0

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=300):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_longest_path(dut):
    # Setup clock if sequential
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational? Assume async
        await Timer(10, units='ns')
    
    # Test cases: (N, M, edges_list, expected_result)
    # Edges are (A, B) pairs (1-indexed)
    test_cases = [
        (4, 3, [(1,2), (1,3), (2,4)], 2),
        (6, 6, [(1,2), (1,3), (2,4), (3,4), (3,5), (5,6)], 5),
        (5, 6, [(1,2), (2,3), (3,4), (4,5), (5,3), (3,1)], 6),
    ]
    
    passed = 0
    failed = 0
    
    for idx, (N, M, edges, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running test case {idx+1}: N={N}, M={M}")
        try:
            # Write inputs
            dut.N.value = N
            dut.M.value = M
            
            # Write edges to arrays
            # Ensure edges list is padded to 16 entries for safety
            padded_edges = edges + [(0,0)] * (16 - len(edges))
            if has_signal(dut, 'edge_A') and has_signal(dut, 'edge_B'):
                await write_edges(dut, padded_edges, M)
            elif has_signal(dut, 'edge_A_0'): # Individual ports
                for i in range(16):
                    port_a = getattr(dut, f'edge_A_{i}')
                    port_b = getattr(dut, f'edge_B_{i}')
                    if i < M:
                        port_a.value = edges[i][0]
                        port_b.value = edges[i][1]
                    else:
                        port_a.value = 0
                        port_b.value = 0
            
            # Start computation
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Check result
            if not has_signal(dut, 'result'):
                raise TestFailure("Result signal not found")
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            
            # Handle signed/unsigned if needed (result is 8-bit unsigned here)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"Test {idx+1} PASSED: result={result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"Test {idx+1} FAILED: {e}")
            failed += 1
        
        # Reset for next test
        if has_signal(dut, 'rst_n'):
            await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")
