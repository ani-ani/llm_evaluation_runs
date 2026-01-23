import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
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
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# TESTBENCH
# ============================================================================

DATA_WIDTH = 10
ARRAY_SIZE = 100
RESULT_WIDTH = 20
CLK_PERIOD_NS = 10
MAX_CYCLES = 200

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_coin_game(dut):
    """Test the coin_game module with various test cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (n, coins_list, expected_result, description)
    test_cases = [
        (1, [1], -1, "n=1 invalid"),
        (2, [707, 629], -1, "n=2 even"),
        (3, [1, 2, 3], 3, "Sample 1"),
        (3, [868, 762, 256], 868, "n=3"),
        (5, [86, 458, 321, 157, 829], 1150, "n=5"),
        (5, [2, 2, 1, 1, 1], 3, "n=5 small coins"),
        (5, [2, 1, 2, 2, 1], 4, "n=5 mixed coins"),
        (7, [760, 154, 34, 77, 792, 950, 159], 2502, "n=7")
    ]
    
    passed = 0
    failed = 0
    
    for n, coins, expected, description in test_cases:
        dut._log.info(f"\nTest: {description}")
        
        # Drive n
        dut.n.value = n
        
        # Drive coin array (element by element)
        for i in range(ARRAY_SIZE):
            if i < len(coins):
                dut.a[i].value = clamp_to_width(coins[i], DATA_WIDTH)
            else:
                dut.a[i].value = 0
        
        # Start computation
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done with timeout
        cycles = 0
        while not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > MAX_CYCLES:
                raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result is undefined (X/Z)")
        
        result = int(dut.result.value)
        # Convert from two's complement if needed
        if result >= (1 << (RESULT_WIDTH - 1)):
            result = result - (1 << RESULT_WIDTH)
        
        # Verify
        if result == expected:
            dut._log.info(f"  PASS: result={result}")
            passed += 1
        else:
            dut._log.error(f"  FAIL: expected={expected}, got={result}")
            failed += 1
    
    # Summary
    dut._log.info(f"\n{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
