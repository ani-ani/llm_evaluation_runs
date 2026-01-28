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

def wait_for_signal(dut, signal_name, expected_value=1, max_cycles=1000):
    signal = getattr(dut, signal_name)
    for _ in range(max_cycles):
        yield RisingEdge(dut.clk)
        if is_value_defined(signal.value) and int(signal.value) == expected_value:
            return True
    raise TestFailure(f"Timeout waiting for {signal_name}")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=10, timeout_unit='ms')
async def test_closest_pair(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test case 1: Example from problem
    # Input: [1, 0, 0, -1] -> prefix: [0, 1, 1, 1, 0]
    # Points: (0,1), (1,1), (2,1), (3,0)
    # Min distance should be 1
    cocotb.log.info("Test 1: Example case [1, 0, 0, -1]")
    dut.arr_0.value = clamp_to_width(1, 8)
    dut.arr_1.value = clamp_to_width(0, 8)
    dut.arr_2.value = clamp_to_width(0, 8)
    dut.arr_3.value = clamp_to_width(-1 & 0xFF, 8)  # Signed value
    dut.arr_4.value = 0
    dut.arr_5.value = 0
    dut.arr_6.value = 0
    dut.arr_7.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done with timeout
    done = await wait_for_signal(dut, 'done', expected_value=1, max_cycles=200)
    
    result = int(dut.result.value)
    expected = 1
    cocotb.log.info(f"Result: {result}, Expected: {expected}")
    if result != expected:
        raise TestFailure(f"Test 1 failed: expected {expected}, got {result}")
    
    # Test case 2: Second example
    await RisingEdge(dut.clk)
    cocotb.log.info("Test 2: Example case [1, -1]")
    dut.arr_0.value = clamp_to_width(1, 8)
    dut.arr_1.value = clamp_to_width(-1 & 0xFF, 8)
    dut.arr_2.value = 0
    dut.arr_3.value = 0
    dut.arr_4.value = 0
    dut.arr_5.value = 0
    dut.arr_6.value = 0
    dut.arr_7.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    done = await wait_for_signal(dut, 'done', expected_value=1, max_cycles=200)
    
    result = int(dut.result.value)
    expected = 2
    cocotb.log.info(f"Result: {result}, Expected: {expected}")
    if result != expected:
        raise TestFailure(f"Test 2 failed: expected {expected}, got {result}")
    
    # Test case 3: Zero array
    await RisingEdge(dut.clk)
    cocotb.log.info("Test 3: Zero array [0, 0, 0, 0]")
    dut.arr_0.value = 0
    dut.arr_1.value = 0
    dut.arr_2.value = 0
    dut.arr_3.value = 0
    dut.arr_4.value = 0
    dut.arr_5.value = 0
    dut.arr_6.value = 0
    dut.arr_7.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    done = await wait_for_signal(dut, 'done', expected_value=1, max_cycles=200)
    
    result = int(dut.result.value)
    # All points at (0,0), (1,0), (2,0), (3,0) -> min distance is 1
    expected = 1
    cocotb.log.info(f"Result: {result}, Expected: {expected}")
    if result != expected:
        raise TestFailure(f"Test 3 failed: expected {expected}, got {result}")
    
    cocotb.log.info("All tests passed!")
