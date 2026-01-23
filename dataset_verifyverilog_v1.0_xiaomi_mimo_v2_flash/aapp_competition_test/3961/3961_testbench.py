import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 4      # For n and p values (max 8, so 4 bits)
RESULT_WIDTH = 32
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

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

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
async def test_maze_solver(dut):
    """Main test function for maze solver."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, p_list, expected_result, description)
    # p_list is 1-indexed as per problem
    test_cases = [
        (2, [1, 2], 4, "n=2, p=[1,2]"),
        (4, [1, 1, 2, 3], 20, "n=4, p=[1,1,2,3]"),
        (5, [1, 1, 1, 1, 1], 62, "n=5, p=[1,1,1,1,1]"),
        (1, [1], 2, "n=1, p=[1]"),
        (3, [1, 1, 3], 8, "n=3, p=[1,1,3]"),
        (7, [1, 2, 1, 3, 1, 2, 1], 154, "n=7, p=[1,2,1,3,1,2,1]"),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (n, p_list, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {test_idx+1}: {description}")
        
        try:
            # Write n value
            dut.n.value = clamp_to_width(n, DATA_WIDTH)
            
            # Write p values to individual ports p_0 to p_7
            # Clear all first
            for i in range(8):
                port_name = f'p_{i}'
                if has_signal(dut, port_name):
                    getattr(dut, port_name).value = 0
            
            # Write the actual p values
            for i in range(len(p_list)):
                port_name = f'p_{i}'
                if has_signal(dut, port_name):
                    p_val = p_list[i]
                    getattr(dut, port_name).value = clamp_to_width(p_val, DATA_WIDTH)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Verify
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