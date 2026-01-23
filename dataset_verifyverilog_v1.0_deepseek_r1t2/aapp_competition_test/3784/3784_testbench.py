import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_world_counter(dut):
    'Test the world_counter module with all provided test cases.'
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases from the problem
    test_cases = [
        (3, 2, 6),
        (4, 4, 3),
        (7, 3, 1196),
        (31, 8, 64921457),
        (1, 1, 0),
        (10, 2, 141356),
        (33, 22, 804201731),
        (50, 50, 3),
        (1, 2, 1),
        (1, 3, 0),
        (2, 1, 0),
        (2, 2, 2),
        (2, 3, 1),
        (3, 1, 0),
        (3, 3, 3),
        (3, 4, 1),
        (4, 1, 0),
        (4, 2, 20),
        (4, 3, 15),
        (4, 5, 1),
        (5, 1, 0),
        (5, 2, 78),
        (5, 3, 60),
        (5, 4, 18),
        (5, 5, 3),
        (5, 6, 1),
        (6, 1, 0),
        (6, 2, 320),
        (6, 3, 269),
        (6, 4, 90),
        (6, 5, 19),
        (6, 6, 3),
        (6, 7, 1),
        (7, 1, 0),
        (7, 2, 1404),
        (7, 4, 452),
        (7, 5, 102),
        (7, 6, 19),
        (7, 7, 3),
        (7, 8, 1),
        (8, 5, 566),
        (9, 2, 29660),
        (10, 4, 55564),
        (15, 12, 625),
        (45, 19, 486112971),
        (48, 20, 804531912),
        (49, 2, 987390633),
        (50, 2, 637245807),
        (50, 33, 805999139),
        (50, 49, 19),
    ]
    
    for n, m, expected in test_cases:
        # Set inputs
        dut.n.value = n
        dut.m.value = m
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 1000
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure(f'Timeout waiting for done for n={n}, m={m}')
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f'Result undefined for n={n}, m={m}')
        
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f'Test failed for n={n}, m={m}: expected {expected}, got {result}')
        else:
            dut._log.info(f'Test passed for n={n}, m={m}: result={result}')
    
    dut._log.info('All tests passed!')