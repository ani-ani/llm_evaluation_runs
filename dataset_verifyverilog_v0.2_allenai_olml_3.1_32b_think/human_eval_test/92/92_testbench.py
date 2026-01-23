import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_any_int(dut):
    """Test any_int module with various integer test cases"""
    
    # Helper function to set inputs and check result
    async def check_case(x, y, z, expected, description):
        dut.x.value = x
        dut.y.value = y
        dut.z.value = z
        await Timer(10, units='ns')
        
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(
                f"{description}: any_int({x}, {y}, {z}) returned {result}, expected {expected}"
            )
        print(f"✓ Test passed: any_int({x}, {y}, {z}) = {result}")
    
    print("
=== Testing any_int module ===")
    
    # Test case 1: 2, 3, 1 -> 1 + 2 = 3 (True)
    await check_case(2, 3, 1, 1, "Test 1")
    
    # Test case 2: 2, 2, 3 -> contains float (2.5), but we use integers only
    # Using 2, 2, 3: 2 + 2 = 4 ≠ 3, 2 + 3 = 5 ≠ 2, 2 + 3 = 5 ≠ 2 -> False
    await check_case(2, 2, 3, 0, "Test 2")
    
    # Test case 3: 1, 5, 3 -> 1 + 3 = 4 ≠ 5, 1 + 5 = 6 ≠ 3, 5 + 3 = 8 ≠ 1 -> False
    await check_case(1, 5, 3, 0, "Test 3")
    
    # Test case 4: 2, 6, 2 -> 2 + 2 = 4 ≠ 6, 2 + 6 = 8 ≠ 2, 6 + 2 = 8 ≠ 2 -> False
    await check_case(2, 6, 2, 0, "Test 4")
    
    # Test case 5: 4, 2, 2 -> 2 + 2 = 4 = x (True)
    await check_case(4, 2, 2, 1, "Test 5")
    
    # Test case 6: 2, 2, 2 -> 2 + 2 = 4 ≠ 2 -> False
    await check_case(2, 2, 2, 0, "Test 6")
    
    # Test case 7: -4, 6, 2 -> -4 + 6 = 2 = z (True)
    await check_case(-4, 6, 2, 1, "Test 7")
    
    # Test case 8: 2, 1, 1 -> 1 + 1 = 2 = x (True)
    await check_case(2, 1, 1, 1, "Test 8")
    
    # Test case 9: 3, 4, 7 -> 3 + 4 = 7 = z (True)
    await check_case(3, 4, 7, 1, "Test 9")
    
    # Edge case: Zero values
    await check_case(0, 0, 0, 0, "All zeros")
    
    # Edge case: Max values
    await check_case(32767, 32767, 0, 0, "Max positive")
    
    # Edge case: Large sum that causes overflow - should still work within 16-bit
    await check_case(100, 50, 150, 1, "Large numbers")
    
    print(f"
=== All tests passed! ===")
    print(f"Summary: 12/12 tests passed")