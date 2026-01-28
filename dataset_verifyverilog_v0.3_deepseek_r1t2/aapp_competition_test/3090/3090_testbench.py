import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================
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

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 500000  # Enough for exhaustive search up to 4x4

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================
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

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=200, timeout_unit="ms")
async def test_wireless_coverage(dut):
    """Test the wireless_coverage module with given examples."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset DUT
    await reset_dut(dut)
    
    # Define test cases
    test_cases = [
        {
            "N": 2, "M": 3, "K": 4,
            "costs": [10, 1, 3, 0, 1, 20],  # Flattened row-major
            "expected": 9
        },
        {
            "N": 2, "M": 3, "K": 100,
            "costs": [10, 1, 10, 10, 1, 10],
            "expected": 21
        },
        {
            "N": 2, "M": 2, "K": 1,
            "costs": [10, 10, 10, 10],
            "expected": 4
        }
    ]
    
    for idx, tc in enumerate(test_cases):
        dut._log.info(f"\nTest case {idx+1}: N={tc['N']}, M={tc['M']}, K={tc['K']}")
        
        # Set N, M, K
        dut.N.value = tc['N']
        dut.M.value = tc['M']
        dut.K.value = tc['K']
        
        # Set costs for 4x4 grid (16 inputs). Fill given costs, rest to 0.
        # We'll set all 16 cost inputs; for indices beyond provided costs, set 0.
        # Map to the Verilog port names: cost00, cost01, ... cost33
        cost_names = [
            'cost00', 'cost01', 'cost02', 'cost03',
            'cost10', 'cost11', 'cost12', 'cost13',
            'cost20', 'cost21', 'cost22', 'cost23',
            'cost30', 'cost31', 'cost32', 'cost33'
        ]
        
        for i in range(16):
            if i < len(tc['costs']):
                val = clamp_to_width(tc['costs'][i], DATA_WIDTH)
            else:
                val = 0
            getattr(dut, cost_names[i]).value = val
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined (X/Z)")
        result = int(dut.result.value)
        expected = tc['expected']
        
        if result != expected:
            raise TestFailure(f"Test {idx+1} failed: expected {expected}, got {result}")
        else:
            dut._log.info(f"  PASS: result = {result}")
    
    dut._log.info("\nAll tests passed!")
