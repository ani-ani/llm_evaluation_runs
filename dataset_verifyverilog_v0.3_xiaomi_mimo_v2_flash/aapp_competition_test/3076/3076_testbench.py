import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 32
SIZE_WIDTH = 9
N_WIDTH = 3
K_WIDTH = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 200
ARRAY_SIZE = 8

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut):
    """Wait for done signal with timeout."""
    for cycle in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {MAX_CYCLES} cycles")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_knapsack_solver(dut):
    """Test the knapsack solver module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases adapted to HDL constraints
    test_cases = [
        {
            "n": 4,
            "k": 9,
            "jewels": [(2, 8), (1, 1), (3, 4), (5, 100)],
            "expected": [1, 8, 9, 9, 100, 101, 108, 109, 109],
            "description": "Sample 1: 4 jewels, max capacity 9"
        },
        {
            "n": 5,
            "k": 7,
            "jewels": [(2, 2), (3, 8), (2, 7), (2, 4), (3, 8)],
            "expected": [0, 7, 8, 11, 15, 16, 19],
            "description": "Sample 2: 5 jewels, max capacity 7"
        },
        {
            "n": 2,
            "k": 6,
            "jewels": [(300, 1), (300, 2)],
            "expected": [0, 0, 0, 0, 0, 0],
            "description": "Sample 3: Large sizes, no fits"
        }
    ]
    
    passed = 0
    failed = 0
    
    for test_case in test_cases:
        n = test_case["n"]
        k = test_case["k"]
        jewels = test_case["jewels"]
        expected = test_case["expected"]
        description = test_case["description"]
        
        cocotb.log.info(f"\nTest: {description}")
        cocotb.log.info(f"  n={n}, k={k}")
        
        try:
            # Set control inputs
            dut.n.value = n
            dut.k.value = k
            
            # Set jewel data
            for i in range(8):
                if i < len(jewels):
                    s_val = jewels[i][0]
                    v_val = jewels[i][1]
                else:
                    s_val = 0
                    v_val = 0
                
                # Clamp values to width
                s_clamped = clamp_to_width(s_val, SIZE_WIDTH)
                v_clamped = clamp_to_width(v_val, DATA_WIDTH)
                
                # Assign to individual ports
                getattr(dut, f's_{i}').value = s_clamped
                getattr(dut, f'v_{i}').value = v_clamped
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read results for capacities 1..k
            results = []
            for i in range(1, k + 1):
                result_signal = getattr(dut, f'result_{i}')
                if is_value_defined(result_signal.value):
                    results.append(int(result_signal.value))
                else:
                    raise TestFailure(f"Result_{i} is undefined (X/Z)")
            
            # Verify results
            if results != expected:
                raise TestFailure(f"Expected {expected}, got {results}")
            
            cocotb.log.info(f"  PASS: {results}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")