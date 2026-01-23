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

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# ============================================================================
# TEST CONFIGURATION
# ============================================================================

DATA_WIDTH = 8
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_reconstruct(dut):
    """Test the reconstruct module for N=4."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (B0, B1, B2, B3) -> (A0, A1, A2, A3)
    test_cases = [
        # Example from problem
        (20, 15, 17, 14, 5, 8, 2, 7),
        # Simple symmetric case
        (6, 6, 6, 6, 2, 2, 2, 2),
    ]
    
    passed = 0
    failed = 0
    
    for i, (b0, b1, b2, b3, a0_exp, a1_exp, a2_exp, a3_exp) in enumerate(test_cases):
        cocotb.log.info(f"Test case {i+1}: B=({b0},{b1},{b2},{b3}) -> Expected A=({a0_exp},{a1_exp},{a2_exp},{a3_exp})")
        
        # Assign inputs
        dut.B0.value = clamp_to_width(b0, DATA_WIDTH)
        dut.B1.value = clamp_to_width(b1, DATA_WIDTH)
        dut.B2.value = clamp_to_width(b2, DATA_WIDTH)
        dut.B3.value = clamp_to_width(b3, DATA_WIDTH)
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (should be set on next cycle)
        await RisingEdge(dut.clk)
        
        # Check done signal
        if not is_value_defined(dut.done.value) or int(dut.done.value) != 1:
            cocotb.log.error(f"  FAIL: done signal not asserted")
            failed += 1
            continue
        
        # Read outputs
        a0 = int(dut.A0.value)
        a1 = int(dut.A1.value)
        a2 = int(dut.A2.value)
        a3 = int(dut.A3.value)
        
        # Verify results
        errors = []
        if a0 != a0_exp:
            errors.append(f"A0: expected {a0_exp}, got {a0}")
        if a1 != a1_exp:
            errors.append(f"A1: expected {a1_exp}, got {a1}")
        if a2 != a2_exp:
            errors.append(f"A2: expected {a2_exp}, got {a2}")
        if a3 != a3_exp:
            errors.append(f"A3: expected {a3_exp}, got {a3}")
        
        if errors:
            cocotb.log.error(f"  FAIL: {'; '.join(errors)}")
            failed += 1
        else:
            cocotb.log.info(f"  PASS: A=({a0},{a1},{a2},{a3})")
            passed += 1
    
    # Summary
    total = passed + failed
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{total} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
