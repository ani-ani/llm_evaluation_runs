import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
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

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Constants
CLK_NS = 10
MAX_CYCLES = 5000
DATA_WIDTH = 16
CITIZEN_MAX = 128

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
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

async def pack_array(vals, bits=16):
    """Pack list of values into a single integer for the packed input ports"""
    packed = 0
    for i, v in enumerate(vals):
        packed |= (clamp_to_width(v, bits) << (i * bits))
    return packed

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_min_total_distance(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (citizens (x,y), max_dist, expected result, description)
    test_cases = [
        # Sample 1: 5 citizens, d=10
        ([3, 1, 4, 1, 5, 9, 2, 6, 5, 3], 10, 18, "Sample 1: d=10"),
        # Sample 2: 5 citizens, d=5
        ([3, 1, 4, 1, 5, 9, 2, 6, 5, 3], 5, 20, "Sample 2: d=5"),
        # Sample 3: 5 citizens, d=4 (impossible)
        ([3, 1, 4, 1, 5, 9, 2, 6, 5, 3], 4, 0, "Sample 3: d=4 (impossible)"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (citizen_flat, max_dist, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        # Prepare citizen data
        n = len(citizen_flat) // 2
        citizens_x = []
        citizens_y = []
        for j in range(n):
            citizens_x.append(citizen_flat[2*j])
            citizens_y.append(citizen_flat[2*j+1])
        
        # Pack into 128-bit registers
        packed_x = 0
        packed_y = 0
        for j in range(min(n, 8)):  # We'll only use first 8 citizens for hardware
            packed_x |= (clamp_to_width(citizens_x[j], 16) << (j * 16))
            packed_y |= (clamp_to_width(citizens_y[j], 16) << (j * 16))
        
        # Set inputs
        dut.citizen_count.value = n
        dut.citizen_x.value = packed_x
        dut.citizen_y.value = packed_y
        dut.max_dist.value = max_dist
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        try:
            await wait_for_done(dut, MAX_CYCLES)
            
            # Read results
            result_val = int(dut.result.value)
            impossible_val = int(dut.impossible.value)
            
            if impossible_val == 1:
                actual_result = 0  # Mark as impossible in our expectation
                result_desc = "impossible"
            else:
                actual_result = result_val
                result_desc = str(actual_result)
            
            # Check expected
            if expected == 0 and impossible_val == 1:
                # Expected impossible and got impossible
                passed += 1
                cocotb.log.info(f"PASS: {desc} - Got {result_desc}")
            elif expected == 0 and impossible_val == 0:
                # Expected impossible but got result
                cocotb.log.error(f"FAIL: {desc} - Expected impossible, got {actual_result}")
                failed += 1
            elif actual_result == expected:
                passed += 1
                cocotb.log.info(f"PASS: {desc} - Got {actual_result}")
            else:
                cocotb.log.error(f"FAIL: {desc} - Expected {expected}, got {actual_result}")
                failed += 1
                
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    cocotb.log.info(f"All {passed} tests passed")