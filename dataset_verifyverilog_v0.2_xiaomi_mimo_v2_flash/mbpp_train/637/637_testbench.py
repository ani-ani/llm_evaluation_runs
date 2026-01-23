import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_noprofit_noloss(dut):
    """Test noprofit_noloss module with multiple test cases"""
    
    # Test 1: Different amounts (1500 vs 1200) - should return False (0)
    dut.actual_cost.value = 1500
    dut.sale_amount.value = 1200
    await Timer(10, units='ns')
    assert dut.result.value == 0, f"Test 1 failed: expected 0 (False), got {dut.result.value}"
    print("Test 1 passed: noprofit_noloss(1500, 1200) = False")
    
    # Test 2: Same amounts (100 vs 100) - should return True (1)
    dut.actual_cost.value = 100
    dut.sale_amount.value = 100
    await Timer(10, units='ns')
    assert dut.result.value == 1, f"Test 2 failed: expected 1 (True), got {dut.result.value}"
    print("Test 2 passed: noprofit_noloss(100, 100) = True")
    
    # Test 3: Different amounts (2000 vs 5000) - should return False (0)
    dut.actual_cost.value = 2000
    dut.sale_amount.value = 5000
    await Timer(10, units='ns')
    assert dut.result.value == 0, f"Test 3 failed: expected 0 (False), got {dut.result.value}"
    print("Test 3 passed: noprofit_noloss(2000, 5000) = False")
    
    # Test 4: Both zero - should return True (1)
    dut.actual_cost.value = 0
    dut.sale_amount.value = 0
    await Timer(10, units='ns')
    assert dut.result.value == 1, f"Test 4 failed: expected 1 (True), got {dut.result.value}"
    print("Test 4 passed: noprofit_noloss(0, 0) = True")
    
    # Test 5: Large equal values - should return True (1)
    dut.actual_cost.value = 4294967295  # max 32-bit
    dut.sale_amount.value = 4294967295
    await Timer(10, units='ns')
    assert dut.result.value == 1, f"Test 5 failed: expected 1 (True), got {dut.result.value}"
    print("Test 5 passed: noprofit_noloss(max, max) = True")
    
    # Test 6: Large different values - should return False (0)
    dut.actual_cost.value = 2147483647
    dut.sale_amount.value = 2147483648
    await Timer(10, units='ns')
    assert dut.result.value == 0, f"Test 6 failed: expected 0 (False), got {dut.result.value}"
    print("Test 6 passed: noprofit_noloss(2147483647, 2147483648) = False")
    
    print("
All 6 tests passed!")
}