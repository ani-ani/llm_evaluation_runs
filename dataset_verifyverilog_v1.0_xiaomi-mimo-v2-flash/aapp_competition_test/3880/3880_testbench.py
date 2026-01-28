import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
DATA_WIDTH = 8
N_WIDTH = 4
MAX_ELEMENTS = 19  # For n=10, 2*10-1 = 19
CLK_NS = 10

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits - 1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def clamp_to_width(v, bits):
    # Handle signed clamping logic if needed, but simple mod arithmetic often works for this size
    # For signed inputs, we need to ensure we fit in the range
    max_val = (1 << (bits - 1)) - 1
    min_val = -(1 << (bits - 1))
    return max(min_val, min(max_val, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def wait_for_signal(dut, signal_name, timeout_cycles=1000):
    # Async generator to wait for signal
    async def wait():
        for _ in range(timeout_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(getattr(dut, signal_name).value) and int(getattr(dut, signal_name).value) == 1:
                return
        raise TestFailure(f"Timeout waiting for {signal_name}")
    return wait()

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'data_valid'): dut.data_valid.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_yaroslav(dut):
    # Setup Clock
    clock = Clock(dut.clk, CLK_NS, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    await reset_dut(dut)

    # Test Cases
    # Format: (n, [elements], expected_sum)
    test_cases = [
        (2, [50, 50, 50], 150),
        (2, [-1, -100, -1], 100),
        (3, [-959, -542, -669, -513, 160], 2843),
        (4, [717, 473, 344, -51, -548, 703, -869], 3603),
        (5, [270, -181, 957, -509, -6, 937, -175, 434, -625], 4094)
    ]

    for n, elements, expected in test_cases:
        cocotb.log.info(f"Testing n={n}, elements={elements}, expected={expected}")
        
        # 1. Start the transaction
        dut.start.value = 1
        dut.n.value = n
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # 2. Feed the data
        # The module expects valid high with data
        # We feed 2*n - 1 elements
        total_elements = 2 * n - 1
        
        for i in range(total_elements):
            val = elements[i]
            dut.data_in.value = from_signed(clamp_to_width(val, DATA_WIDTH), DATA_WIDTH)
            dut.data_valid.value = 1
            await RisingEdge(dut.clk)
        
        dut.data_valid.value = 0
        
        # 3. Wait for done
        await wait_for_signal(dut, 'done', timeout_cycles=500)
        
        # 4. Check result
        # Result is 32-bit signed
        raw_result = int(dut.result.value)
        
        # Convert back to signed Python int
        if raw_result >= (1 << 31):
            result_python = raw_result - (1 << 32)
        else:
            result_python = raw_result
            
        if result_python != expected:
            raise TestFailure(f"Failed for n={n}. Expected {expected}, got {result_python}")
        
        # Reset for next test case
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    cocotb.log.info("All tests passed!")
