import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 16
MAX_CARDS = 100
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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_card_game(dut):
    """Test the card game module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases
    test_cases = [
        {
            "n": 2, "m": 3,
            "jiro": [("ATK", 2000), ("DEF", 1700)],
            "ciel": [2500, 2500, 2500],
            "expected": 3000
        },
        {
            "n": 3, "m": 4,
            "jiro": [("ATK", 10), ("ATK", 100), ("ATK", 1000)],
            "ciel": [1, 11, 101, 1001],
            "expected": 992
        },
        {
            "n": 2, "m": 4,
            "jiro": [("DEF", 0), ("ATK", 0)],
            "ciel": [0, 0, 1, 1],
            "expected": 1
        },
        {
            "n": 1, "m": 1,
            "jiro": [("ATK", 100)],
            "ciel": [99],
            "expected": 0
        },
        {
            "n": 4, "m": 8,
            "jiro": [("DEF", 100), ("DEF", 200), ("DEF", 300), ("ATK", 100)],
            "ciel": [100, 101, 201, 301, 1, 1, 1, 1],
            "expected": 201
        },
    ]
    
    for test_idx, test in enumerate(test_cases):
        dut._log.info(f"\nTest {test_idx+1}: n={test['n']}, m={test['m']}")
        
        # Set n and m
        dut.n.value = test['n']
        dut.m.value = test['m']
        
        # Set Jiro cards
        for i in range(test['n']):
            pos, strength = test['jiro'][i]
            dut.jiro_strength[i].value = strength
            # Set type: 0 for DEF, 1 for ATK
            if pos == "DEF":
                # Clear the bit at position i
                dut.jiro_type.value = dut.jiro_type.value & ~(1 << i)
            else:
                # Set the bit at position i
                dut.jiro_type.value = dut.jiro_type.value | (1 << i)
        
        # Set Ciel cards
        for i in range(test['m']):
            dut.ciel_strength[i].value = test['ciel'][i]
        
        # Start the module
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if is_value_defined(dut.result.value):
            result = int(dut.result.value)
        else:
            raise TestFailure(f"Result is undefined (X/Z)")
        
        expected = test['expected']
        if result != expected:
            raise TestFailure(f"Test {test_idx+1} failed: expected {expected}, got {result}")
        else:
            dut._log.info(f"  PASS: result = {result}")
    
    dut._log.info("\nAll tests passed!")
