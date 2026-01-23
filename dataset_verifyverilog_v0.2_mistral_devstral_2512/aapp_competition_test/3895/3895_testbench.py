import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_function_decomposer(dut):
    """Test function decomposition on multiple cases"""
    
    # Test case 1: n=3, f=[1,2,3] - identity function
    dut.n.value = 3
    dut.f_1.value = 1
    dut.f_2.value = 2
    dut.f_3.value = 3
    dut.f_4.value = 0
    dut.f_5.value = 0
    dut.f_6.value = 0
    dut.f_7.value = 0
    dut.f_8.value = 0
    await Timer(10, units='ns')
    
    assert dut.valid.value == 1, f"Test 1 failed: expected valid=1, got {dut.valid.value}"
    assert dut.m.value == 3, f"Test 1 failed: expected m=3, got {dut.m.value}"
    assert dut.g_1.value == 1 and dut.g_2.value == 2 and dut.g_3.value == 3, "Test 1 failed: g incorrect"
    assert dut.h_1.value == 1 and dut.h_2.value == 2 and dut.h_3.value == 3, "Test 1 failed: h incorrect"
    print("Test 1 passed: n=3, f=[1,2,3]")
    
    # Test case 2: n=3, f=[2,2,2] - constant function
    dut.n.value = 3
    dut.f_1.value = 2
    dut.f_2.value = 2
    dut.f_3.value = 2
    await Timer(10, units='ns')
    
    assert dut.valid.value == 1, f"Test 2 failed: expected valid=1, got {dut.valid.value}"
    assert dut.m.value == 1, f"Test 2 failed: expected m=1, got {dut.m.value}"
    assert dut.g_1.value == 1 and dut.g_2.value == 1 and dut.g_3.value == 1, "Test 2 failed: g incorrect"
    assert dut.h_1.value == 2, "Test 2 failed: h incorrect"
    print("Test 2 passed: n=3, f=[2,2,2]")
    
    # Test case 3: n=2, f=[2,1] - not idempotent
    dut.n.value = 2
    dut.f_1.value = 2
    dut.f_2.value = 1
    await Timer(10, units='ns')
    
    assert dut.valid.value == 0, f"Test 3 failed: expected valid=0, got {dut.valid.value}"
    print("Test 3 passed: n=2, f=[2,1] (invalid)")
    
    # Test case 4: n=1, f=[1] - minimal
    dut.n.value = 1
    dut.f_1.value = 1
    await Timer(10, units='ns')
    
    assert dut.valid.value == 1, f"Test 4 failed: expected valid=1, got {dut.valid.value}"
    assert dut.m.value == 1, f"Test 4 failed: expected m=1, got {dut.m.value}"
    assert dut.g_1.value == 1, "Test 4 failed: g incorrect"
    assert dut.h_1.value == 1, "Test 4 failed: h incorrect"
    print("Test 4 passed: n=1, f=[1]")
    
    # Test case 5: n=4, f=[2,2,4,4] - valid with m=2
    dut.n.value = 4
    dut.f_1.value = 2
    dut.f_2.value = 2
    dut.f_3.value = 4
    dut.f_4.value = 4
    dut.f_5.value = 0
    dut.f_6.value = 0
    dut.f_7.value = 0
    dut.f_8.value = 0
    await Timer(10, units='ns')
    
    assert dut.valid.value == 1, f"Test 5 failed: expected valid=1, got {dut.valid.value}"
    assert dut.m.value == 2, f"Test 5 failed: expected m=2, got {dut.m.value}"
    assert dut.g_1.value == 1 and dut.g_2.value == 1 and dut.g_3.value == 2 and dut.g_4.value == 2, "Test 5 failed: g incorrect"
    assert (dut.h_1.value == 2 and dut.h_2.value == 4) or (dut.h_1.value == 4 and dut.h_2.value == 2), "Test 5 failed: h incorrect"
    print("Test 5 passed: n=4, f=[2,2,4,4]")
    
    # Test case 6: n=3, f=[1,1,2] - not idempotent (f[3]=2, f[2]=1≠2)
    dut.n.value = 3
    dut.f_1.value = 1
    dut.f_2.value = 1
    dut.f_3.value = 2
    await Timer(10, units='ns')
    
    assert dut.valid.value == 0, f"Test 6 failed: expected valid=0, got {dut.valid.value}"
    print("Test 6 passed: n=3, f=[1,1,2] (invalid)")
    
    print("
All 6 tests passed!")