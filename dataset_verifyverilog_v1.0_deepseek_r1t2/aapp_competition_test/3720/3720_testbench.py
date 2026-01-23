import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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
# TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_powers_game(dut):
    """Test the powers_game module."""
    
    # Configuration
    CLK_PERIOD_NS = 10
    MAX_CYCLES = 10000
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases: (n, expected_winner) where 1=Vasya, 0=Petya
    test_cases = [
        (1, 1, "n=1: Vasya wins"),
        (2, 0, "n=2: Petya wins"),
        (3, 1, "n=3: Vasya wins"),
        (4, 1, "n=4: Vasya wins"),
        (5, 1, "n=5: Vasya wins"),
        (6, 1, "n=6: Vasya wins"),
        (7, 1, "n=7: Vasya wins"),
        (8, 0, "n=8: Petya wins"),
        (9, 1, "n=9: Vasya wins"),
        (10, 1, "n=10: Vasya wins"),
        (52, 0, "n=52: Petya wins"),
        (53, 1, "n=53: Vasya wins"),
        (100, 1, "n=100: Vasya wins"),
        (500, 1, "n=500: Vasya wins"),
        (1000, 1, "n=1000: Vasya wins"),
    ]
    
    passed = 0
    failed = 0
    
    for n_input, expected, description in test_cases:
        dut._log.info(f"Testing: {description}")
        
        # Apply input
        dut.n.value = n_input
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        cycles = 0
        done = False
        while cycles < MAX_CYCLES:
            await RisingEdge(dut.clk)
            cycles += 1
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            dut._log.error(f"  TIMEOUT: Done not asserted after {cycles} cycles")
            failed += 1
            continue
        
        # Read winner
        if not is_value_defined(dut.winner.value):
            dut._log.error("  FAIL: Winner is undefined (X/Z)")
            failed += 1
            continue
            
        winner = int(dut.winner.value)
        
        if winner == expected:
            dut._log.info(f"  PASS: winner = {winner} (expected {expected})")
            passed += 1
        else:
            dut._log.error(f"  FAIL: winner = {winner}, expected {expected}")
            failed += 1
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
