import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
CLK_PERIOD_NS = 10
MAX_CYCLES = 200

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut, s_str, length):
    # Pack string into 64-bit integer (8 chars * 8 bits)
    # s[63:56] = char0, s[55:48] = char1, ..., s[7:0] = char7
    packed_val = 0
    for i, char in enumerate(s_str):
        packed_val |= (ord(char) << (56 - i*8))
    
    dut.s.value = packed_val
    dut.length.value = length
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut):
    for cycle in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure("Timeout waiting for done signal")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_count_substrings(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (string, length, expected_count)
    test_cases = [
        ('112112', 6, 6),
        ('111', 3, 6),
        ('1101112', 7, 12),
    ]
    
    for s_str, length, expected in test_cases:
        dut._log.info(f"Testing string='{s_str}', length={length}, expected={expected}")
        
        await start_computation(dut, s_str, length)
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.count.value):
            raise TestFailure(f"Result count is undefined (X/Z)")
        
        result = int(dut.count.value)
        
        if result != expected:
            raise TestFailure(f"Failed: expected {expected}, got {result}")
        
        dut._log.info(f"  PASS: count = {result}")
        
        # Small delay between tests
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)