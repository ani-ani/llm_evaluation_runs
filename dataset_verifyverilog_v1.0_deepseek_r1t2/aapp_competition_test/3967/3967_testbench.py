import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Configuration
DATA_WIDTH = 8
ARRAY_SIZE = 8
K_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 5000

# Helper functions
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

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def write_array(dut, values, element_width):
    """Write values to array elements individually"""
    for i, val in enumerate(values):
        if i < ARRAY_SIZE:
            dut.arr[i].value = clamp_to_width(val, element_width)

async def read_array(dut, size):
    """Read array values"""
    results = []
    for i in range(size):
        if is_value_defined(dut.arr[i].value):
            results.append(int(dut.arr[i].value))
        else:
            results.append(None)
    return results

async def reset_dut(dut):
    """Reset sequence"""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal"""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal"""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

def python_calc_max_d(n, k, a):
    """Reference Python implementation for testing"""
    max_d = 1
    for d in range(1, 257):  # Search up to 256
        total_cut = 0
        for height in a[:n]:
            # ceil(a_i/d) = (a_i + d - 1) // d
            t = ((height + d - 1) // d) * d
            total_cut += t - height
            if total_cut > k:
                break
        if total_cut <= k:
            max_d = d
    return max_d

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_bamboo_cut(dut):
    """Main test for bamboo cutting problem"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Test cases: (n, k, a_list, expected_d)
    test_cases = [
        # Example 1: 3 bamboos, k=4, a=[1,3,5] -> expected=3
        (3, 4, [1, 3, 5], 3),
        # Example 2: 3 bamboos, k=40, a=[10,30,50] -> expected=32
        (3, 40, [10, 30, 50], 32),
        # Additional small test cases
        (2, 0, [5, 7], 1),  # k=0 means no cut allowed
        (1, 100, [255], 256),  # Single bamboo, large k
        (4, 50, [10, 20, 30, 40], 13),  # Multiple bamboos
        (8, 100, [1, 2, 3, 4, 5, 6, 7, 8], 2),  # Many small bamboos
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (n, k, a_list, expected) in enumerate(test_cases):
        dut._log.info(f"\nTest {test_idx+1}: n={n}, k={k}, a={a_list}, expected={expected}")
        
        try:
            # Reset
            await reset_dut(dut)
            
            # Set inputs
            dut.n.value = n
            dut.k.value = k
            await write_array(dut, a_list, DATA_WIDTH)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.max_d.value):
                raise TestFailure("max_d is undefined (X/Z)")
            
            result = int(dut.max_d.value)
            
            # Verify
            if result != expected:
                # Calculate reference to verify test case
                ref = python_calc_max_d(n, k, a_list)
                if ref != expected:
                    dut._log.warning(f"Test case may be wrong: reference gives {ref}")
                raise TestFailure(f"Expected {expected}, got {result} (reference: {ref})")
            
            dut._log.info(f"  PASS: max_d = {result}")
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    dut._log.info(f"\n{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")