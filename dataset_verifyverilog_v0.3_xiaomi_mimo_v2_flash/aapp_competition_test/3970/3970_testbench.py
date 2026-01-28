import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 16
ARRAY_SIZE = 16
RESULT_WIDTH = 5
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

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut):
    for _ in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout: done not asserted after {MAX_CYCLES} cycles")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_k_multiple_free_set(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, k, [arr], expected_count)
    test_cases = [
        (3, 2, [2,4,8], 2),          # {2,8} or {4}
        (10, 2, [1,2,3,4,5,6,7,8,9,10], 6),  # {1,3,5,7,9,10}? Actually algorithm should yield 6
        (1, 1, [1], 1),
        (2, 2, [1,2], 1),            # Cannot have both 1 and 2
        (2, 2, [3,6], 1),            # {3} or {6}
        (4, 3, [1,3,9,27], 2),      # {1,27} or {3,9}
        (5, 1, [5,2,7,3,9], 5),     # All distinct
        (4, 2, [8,4,2,1], 2),       # {8,2} or {4,1}
    ]
    
    for test_idx, (n, k, arr, expected) in enumerate(test_cases):
        dut._log.info(f"Test {test_idx+1}: n={n}, k={k}, arr={arr}, expected={expected}")
        
        # Set n and k
        dut.n.value = n
        dut.k.value = k
        
        # Assign array elements (pad to 16 elements with zeros)
        for i in range(16):
            port_name = f"arr_{i}"
            if i < len(arr):
                val = clamp_to_width(arr[i], DATA_WIDTH)
                getattr(dut, port_name).value = val
            else:
                getattr(dut, port_name).value = 0
        
        # Toggle start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.count.value):
            raise TestFailure(f"Test {test_idx+1}: count is undefined")
        
        result = int(dut.count.value)
        if result != expected:
            raise TestFailure(f"Test {test_idx+1}: Expected {expected}, got {result}")
        
        dut._log.info(f"  PASS: count={result}")
        
        # Reset between tests
        await reset_dut(dut)
    
    dut._log.info("All tests passed!")