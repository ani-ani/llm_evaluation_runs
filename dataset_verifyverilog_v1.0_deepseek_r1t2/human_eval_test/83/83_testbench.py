import cocotb
from cocotb.triggers import Timer

# Helper function to check for defined values
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test()
async def test_starts_one_ends(dut):
    """Test starts_one_ends module with various inputs"""
    
    # Test cases: (n, expected_count)
    test_cases = [
        (1, 1),
        (2, 18),
        (3, 180),
        (4, 1800),
        (5, 18000),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, expected in test_cases:
        # Set input
        dut.n.value = n
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Check if output is defined
        if not is_value_defined(dut.count.value):
            dut._log.error(f"Test n={n}: Output count is undefined (X/Z)")
            continue
            
        result = int(dut.count.value)
        
        if result == expected:
            dut._log.info(f"Test n={n}: Passed (Result={result})")
            passed += 1
        else:
            dut._log.error(f"Test n={n}: Failed (Expected={expected}, Got={result})")
    
    dut._log.info(f"\nSummary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
