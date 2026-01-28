import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8      # Input n width
RESULT_WIDTH = 24   # Output result width

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

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_square_sum_odd(dut):
    """Test sum of squares of first n odd numbers."""
    
    # Detect module type (combinational or sequential)
    is_sequential = has_signal(dut, 'clk') and has_signal(dut, 'done')
    has_start = has_signal(dut, 'start')
    
    if is_sequential:
        # Sequential module - start clock and reset
        from cocotb.clock import Clock
        from cocotb.triggers import RisingEdge
        
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        
        # Reset sequence
        dut.rst_n.value = 0
        if has_start:
            dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test cases: (n, expected_result)
    test_cases = [
        (2, 10),   # 1^2 + 3^2 = 1 + 9 = 10
        (3, 35),   # 1 + 9 + 25 = 35
        (4, 84),   # 1 + 9 + 25 + 49 = 84
        (1, 1),    # Edge case: n=1
        (5, 165),  # Additional test
        (0, 0),    # Edge case: n=0
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_val, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n_val}, expected={expected}")
        
        try:
            # Set input n
            dut.n.value = n_val
            
            if is_sequential:
                # Start computation
                if has_start:
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                    await RisingEdge(dut.clk)
                
                # Wait for done signal
                timeout = 100
                for _ in range(timeout):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        break
                else:
                    raise TestFailure(f"Timeout waiting for done signal")
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result={result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")