import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 16
ARRAY_SIZE = 8
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

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_remainder_game(dut):
    """Test the remainder_game module with scaled test cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, k, [c_0..c_7], expected_result)
    # We use 8-element arrays, padding with zeros for unused elements
    test_cases = [
        (4, 5, [2, 3, 5, 12, 0, 0, 0, 0], 1),
        (2, 7, [2, 3, 0, 0, 0, 0, 0, 0], 0),
        (1, 6, [8, 0, 0, 0, 0, 0, 0, 0], 0),
        (2, 3, [9, 4, 0, 0, 0, 0, 0, 0], 1),
        (4, 16, [19, 16, 13, 9, 0, 0, 0, 0], 1),
        (5, 10, [5, 16, 19, 9, 17, 0, 0, 0], 1),
        (2, 4, [2, 2, 0, 0, 0, 0, 0, 0], 0),
        (3, 8, [2, 4, 11, 0, 0, 0, 0, 0], 0),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, k, c_list, expected) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: n={n}, k={k}, c={c_list[:n]}, expected={'Yes' if expected else 'No'}")
        
        # Set inputs
        dut.n.value = n
        dut.k.value = clamp_to_width(k, DATA_WIDTH)
        
        # Set c_i ports
        for idx in range(ARRAY_SIZE):
            port_name = f'c_{idx}'
            if has_signal(dut, port_name):
                val = c_list[idx] if idx < len(c_list) else 0
                getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)
            else:
                raise TestFailure(f"Signal {port_name} not found")
        
        # Start computation
        await start_computation(dut)
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            dut._log.error(f"Test {i+1} FAIL: result is undefined (X/Z)")
            failed += 1
            continue
        
        result = int(dut.result.value)
        
        if result == expected:
            dut._log.info(f"Test {i+1} PASS: result={result}")
            passed += 1
        else:
            dut._log.error(f"Test {i+1} FAIL: expected {expected}, got {result}")
            failed += 1
    
    dut._log.info(f"\n{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")