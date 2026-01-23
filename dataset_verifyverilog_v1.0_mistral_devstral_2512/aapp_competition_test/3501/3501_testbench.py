import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_CAMELS = 8
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_camel_race(dut):
    """Test the camel_race module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (jaap_bet, jan_bet, thijs_bet, num_camels, expected_result)
    test_cases = [
        # Sample 1: 3 camels, expected 0
        (
            [3, 2, 1, 0, 0, 0, 0, 0],  # Jaap: 3,2,1
            [1, 2, 3, 0, 0, 0, 0, 0],  # Jan: 1,2,3
            [1, 2, 3, 0, 0, 0, 0, 0],  # Thijs: 1,2,3
            3,  # num_camels
            0   # expected result
        ),
        # Sample 2: 4 camels, expected 3
        (
            [2, 3, 1, 4, 0, 0, 0, 0],  # Jaap: 2,3,1,4
            [2, 1, 4, 3, 0, 0, 0, 0],  # Jan: 2,1,4,3
            [2, 4, 3, 1, 0, 0, 0, 0],  # Thijs: 2,4,3,1
            4,  # num_camels
            3   # expected result
        ),
        # Additional test: 2 camels in same order
        (
            [1, 2, 0, 0, 0, 0, 0, 0],
            [1, 2, 0, 0, 0, 0, 0, 0],
            [1, 2, 0, 0, 0, 0, 0, 0],
            2,
            1
        ),
        # Additional test: 2 camels in opposite orders
        (
            [1, 2, 0, 0, 0, 0, 0, 0],
            [2, 1, 0, 0, 0, 0, 0, 0],
            [1, 2, 0, 0, 0, 0, 0, 0],
            2,
            0
        ),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (jaap, jan, thijs, num_camels, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {test_idx + 1}: {num_camels} camels, expected {expected}")
        
        try:
            # Write inputs - individual array assignment
            for i in range(MAX_CAMELS):
                if has_signal(dut, f'jaap_bet_{i}'):
                    getattr(dut, f'jaap_bet_{i}').value = jaap[i]
                    getattr(dut, f'jan_bet_{i}').value = jan[i]
                    getattr(dut, f'thijs_bet_{i}').value = thijs[i]
                else:
                    # Fallback to indexed arrays
                    dut.jaap_bet[i].value = jaap[i]
                    dut.jan_bet[i].value = jan[i]
                    dut.thijs_bet[i].value = thijs[i]
            
            # Set num_camels
            if has_signal(dut, 'num_camels'):
                dut.num_camels.value = num_camels
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
