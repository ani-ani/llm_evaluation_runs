import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 16
MAX_VAL = (1 << DATA_WIDTH) - 1  # 65535

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

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_loss_amount(dut):
    """Test loss_amount module with multiple test cases."""
    
    # Test cases: (actual_cost, sale_amount, expected_loss, description)
    test_cases = [
        (1500, 1200, 0, "sale < cost: no loss"),
        (100, 200, 100, "sale > cost: loss of 100"),
        (2000, 5000, 3000, "sale > cost: loss of 3000"),
        (0, 0, 0, "equal: no loss"),
        (1000, 1000, 0, "equal: no loss"),
        (5000, 1000, 0, "sale < cost: no loss"),
        (1, 65535, 65534, "large loss"),
        (0, 1, 1, "minimum loss"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (actual_cost, sale_amount, expected_loss, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Input: actual_cost={actual_cost}, sale_amount={sale_amount}")
        
        try:
            # Set inputs
            dut.actual_cost.value = actual_cost
            dut.sale_amount.value = sale_amount
            
            # Wait for combinational logic to settle
            await Timer(10, units='ns')
            
            # Read output
            if not is_value_defined(dut.loss.value):
                raise TestFailure(f"Output 'loss' is undefined (X/Z)")
            
            result = int(dut.loss.value)
            
            # Verify
            if result != expected_loss:
                raise TestFailure(f"Expected {expected_loss}, got {result}")
            
            cocotb.log.info(f"  Result: {result} [PASS]")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")