import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 16
IDX_WIDTH = 6
MAX_TUNNELS = 32
MAX_STATIONS = 16
CLK_NS = 10
MAX_CYCLES = 3000

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def feed_tunnel_data(dut, tunnels, N, M):
    """Feed tunnel data to the dut (assuming sequential interface or array assignment)"""
    dut.N.value = N
    dut.M.value = M
    
    # Check if using individual signals or array
    has_a_array = has_signal(dut, 'a')
    has_l_known = has_signal(dut, 'l_known')
    
    # First, write known data (assuming array format for simplicity)
    # Note: In real test, adapt based on actual interface (packed vs unpacked)
    for i in range(M):
        a_val, b_val, l_val, l_known_val, c_val = tunnels[i]
        if has_a_array:
            # Array interface
            dut.a[i].value = a_val
            dut.b[i].value = b_val
            dut.l[i].value = l_val
            if has_l_known:
                dut.l_known[i].value = l_known_val
            else:
                # If l_known not separate, encode in l_val
                pass
            dut.c[i].value = c_val
        else:
            # Individual signals arr_0, arr_1...
            prefix = f'tunnel_{i}_'
            if has_signal(dut, prefix + 'a'):
                getattr(dut, prefix + 'a').value = a_val
                getattr(dut, prefix + 'b').value = b_val
                getattr(dut, prefix + 'l').value = l_val
                if has_signal(dut, prefix + 'l_known'):
                    getattr(dut, prefix + 'l_known').value = l_known_val
                getattr(dut, prefix + 'c').value = c_val
    
    # Wait a cycle for data to settle
    await Timer(10, units='ns')

async def process_results(dut, expected_results):
    """Process results sequentially as done pulses are received"""
    results = []
    for exp_val in expected_results:
        await wait_for_done(dut)
        
        result_val = int(dut.result.value)
        tunnel_idx = int(dut.tunnel_idx.value)
        
        results.append(result_val)
        
        if result_val != exp_val:
            raise TestFailure(f"Tunnel {tunnel_idx}: Expected {exp_val}, got {result_val}")
        
        await RisingEdge(dut.clk)
        
    return results

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_subway_min_lengths(dut):
    """Test module with sample inputs"""
    
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test Case 1: Sample Input 1
    # 3 3
    # 1 2 5 1
    # 2 3 3 1
    # 3 1 ? 0
    # Expected: 5
    N1, M1 = 3, 3
    tunnels1 = [
        (1, 2, 5, 1, 1),  # a, b, l, l_known, c
        (2, 3, 3, 1, 1),
        (3, 1, 0, 0, 0),  # l=0 (unknown), l_known=0
    ]
    expected1 = [5]
    
    # Test Case 2: Sample Input 2
    # 4 3
    # 1 2 ? 1
    # 1 3 ? 1
    # 2 4 ? 1
    # Expected: 1, 1, 1
    N2, M2 = 4, 3
    tunnels2 = [
        (1, 2, 0, 0, 1),
        (1, 3, 0, 0, 1),
        (2, 4, 0, 0, 1),
    ]
    expected2 = [1, 1, 1]
    
    test_cases = [
        (N1, M1, tunnels1, expected1, "Sample 1: Non-cable edge with cable path"),
        (N2, M2, tunnels2, expected2, "Sample 2: All cable edges unknown"),
    ]
    
    passed = 0
    failed = 0
    
    for tc_idx, (N, M, tunnels, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"\n=== Test Case {tc_idx+1}: {desc} ===")
        cocotb.log.info(f"N={N}, M={M}")
        
        try:
            # Feed data
            await feed_tunnel_data(dut, tunnels, N, M)
            
            if is_seq:
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Process results
                results = await process_results(dut, expected)
                cocotb.log.info(f"Test {tc_idx+1} passed. Results: {results}")
            else:
                # Combinational: read all results at once
                # Check how results are exposed
                if has_signal(dut, 'result'):
                    result_val = int(dut.result.value)
                    cocotb.log.info(f"Result: {result_val}")
                await Timer(100, units='ns')
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"Test {tc_idx+1} FAILED: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"Test {tc_idx+1} ERROR: {e}")
            failed += 1
    
    # Add a stress test with random data (optional, keep it simple)
    # For now, focus on core test cases
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed, {passed} passed")
    else:
        cocotb.log.info(f"All {passed} tests passed!")
