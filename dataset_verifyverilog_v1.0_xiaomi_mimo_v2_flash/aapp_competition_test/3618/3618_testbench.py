import cocotb
from cocotb.triggers import Timer, RisingEdge
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

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_best_friend_pairs(dut):
    """Test the best_friend_pairs module."""
    
    # Detect if sequential or combinational
    is_sequential = has_signal(dut, 'clk') and has_signal(dut, 'done')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        # Reset if present
        if has_signal(dut, 'rst_n'):
            dut.rst_n.value = 0
            await RisingEdge(dut.clk)
            dut.rst_n.value = 1
            await RisingEdge(dut.clk)
    else:
        # Combinational module
        pass
    
    # Test cases: (n, expected_result)
    test_cases = [
        (1, 10),
        (2, 570),
        (3, 46242),
    ]
    
    for n_val, expected in test_cases:
        # Set n input
        if has_signal(dut, 'n'):
            dut.n.value = n_val
        else:
            raise TestFailure("Signal 'n' not found")
        
        # Wait for combinational propagation
        await Timer(100, units='ns')
        
        # Read result
        if not has_signal(dut, 'result'):
            raise TestFailure("Signal 'result' not found")
        
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined for n={n_val}")
        
        result = int(dut.result.value)
        
        if result != expected:
            raise TestFailure(f"For n={n_val}: expected {expected}, got {result}")
        
        dut._log.info(f"n={n_val}: result={result} [PASS]")
    
    dut._log.info(f"All tests passed.")