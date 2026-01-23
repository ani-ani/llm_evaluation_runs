import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
ARRAY_SIZE = 16
RESULT_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

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
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

def write_array(dut, values):
    """Write array values to individual ports"""
    for i in range(ARRAY_SIZE):
        port_name = f"arr_{i}"
        if hasattr(dut, port_name):
            val = values[i] if i < len(values) else 0
            getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)

def read_result(dut):
    return int(dut.color_count.value)

# Main test
@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_paint_the_numbers(dut):
    """Test the paint_the_numbers module"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, input_array, expected_colors, description)
    test_cases = [
        (6, [10, 2, 3, 5, 4, 2], 3, "Example 1"),
        (4, [100, 100, 100, 100], 1, "Example 2"),
        (8, [7, 6, 5, 4, 3, 2, 2, 3], 4, "Example 3"),
        (1, [1], 1, "Single element"),
        (1, [100], 1, "Single 100"),
        (10, [7, 70, 8, 9, 8, 9, 35, 1, 99, 27], 4, "Mixed numbers"),
        (5, [40, 80, 40, 40, 40], 1, "All multiples of 40"),
        (2, [1, 2], 1, "1 and 2"),
        (2, [2, 3], 2, "Primes"),
        (3, [6, 2, 3], 1, "Divisible by 2 and 3")
    ]
    
    for idx, (n, arr, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {idx+1}: {desc}")
        
        # Write n
        dut.n.value = n
        
        # Write array (pad to 16 elements)
        padded_arr = arr + [0]*(ARRAY_SIZE - len(arr))
        write_array(dut, padded_arr)
        
        # Start computation
        await start_computation(dut)
        
        # Wait for completion
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.color_count.value):
            raise TestFailure(f"Result is undefined (X/Z)")
        
        result = read_result(dut)
        
        # Verify
        if result != expected:
            raise TestFailure(f"Test {idx+1} ({desc}): Expected {expected}, got {result}")
        
        cocotb.log.info(f"  PASS: {result} colors")
        
        # Reset for next test
        await reset_dut(dut)
    
    cocotb.log.info("\nAll tests passed!")
