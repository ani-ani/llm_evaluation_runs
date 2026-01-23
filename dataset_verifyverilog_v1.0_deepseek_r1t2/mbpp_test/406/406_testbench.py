import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

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
async def test_parity_calculator(dut):
    """Test parity calculation for various inputs."""
    
    # Test cases: (input, expected_parity, description)
    # parity=1 means odd parity, parity=0 means even parity
    test_cases = [
        (12, 0, "12 = 0b1100 has 2 ones -> even parity"),
        (7, 1, "7 = 0b111 has 3 ones -> odd parity"),
        (10, 0, "10 = 0b1010 has 2 ones -> even parity"),
        (0, 0, "0 has 0 ones -> even parity"),
        (1, 1, "1 = 0b1 has 1 one -> odd parity"),
        (15, 0, "15 = 0b1111 has 4 ones -> even parity"),
        (255, 0, "255 = 0b11111111 has 8 ones -> even parity"),
        (256, 1, "256 = 0b100000000 has 1 one -> odd parity"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_val, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Input: {input_val} (0x{input_val:X}, 0b{input_val:b})")
        
        try:
            # Assign input
            dut.num.value = input_val
            
            # Wait for combinational logic to settle
            await Timer(10, units='ns')
            
            # Read result
            if not is_value_defined(dut.parity.value):
                raise TestFailure(f"Parity output is undefined (X/Z)")
            
            result = int(dut.parity.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected parity={expected}, got {result}")
            
            cocotb.log.info(f"  PASS: parity = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")