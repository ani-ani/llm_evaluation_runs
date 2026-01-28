import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

DATA_WIDTH = 16

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    if v < 0:
        return 0
    elif v > max_val:
        return max_val
    return v

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_noprofit_noloss(dut):
    """Test no profit no loss comparator"""
    # Test cases: (actual_cost, sale_amount, expected_equal)
    test_cases = [
        (1500, 1200, 0),  # Different -> no equal
        (100, 100, 1),    # Equal -> equal
        (2000, 5000, 0),  # Different -> no equal
        (0, 0, 1),        # Edge case: both zero
        (65535, 65535, 1),  # Edge case: max value
        (32768, 16384, 0),  # Large difference
    ]
    
    passed = 0
    failed = 0
    
    for i, (cost, sale, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: actual_cost={cost}, sale_amount={sale}")
        try:
            # Clamp values to 16-bit
            cost_clamped = clamp_to_width(cost, DATA_WIDTH)
            sale_clamped = clamp_to_width(sale, DATA_WIDTH)
            
            # Assign inputs
            dut.actual_cost.value = cost_clamped
            dut.sale_amount.value = sale_clamped
            
            # Wait for combinational logic to settle
            await Timer(10, units='ns')
            
            # Check output
            if not is_value_defined(dut.equal.value):
                raise TestFailure("Output 'equal' is undefined")
            
            result = int(dut.equal.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: equal={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All {passed} tests passed")