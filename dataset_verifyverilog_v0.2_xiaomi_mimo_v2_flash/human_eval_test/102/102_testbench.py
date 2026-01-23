import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_choose_num(dut):
    """Test choose_num module with various test cases"""
    
    # Helper function to run a test
    async def test_case(x, y, expected):
        dut.x.value = x
        dut.y.value = y
        await Timer(1, units='ns')
        result = int(dut.result.value)
        assert result == expected, f"x={x}, y={y}: expected {expected}, got {result}"
        print(f"Test passed: choose_num({x}, {y}) = {result}")
    
    print("
=== Testing choose_num module ===")
    
    # Test case 1: choose_num(12, 15) = 14
    await test_case(12, 15, 14)
    
    # Test case 2: choose_num(13, 12) = -1 (x > y)
    await test_case(13, 12, 0xFFFF)
    
    # Test case 3: choose_num(33, 12354) = 12354
    await test_case(33, 12354, 12354)
    
    # Test case 4: choose_num(5234, 5233) = -1 (x > y)
    await test_case(5234, 5233, 0xFFFF)
    
    # Test case 5: choose_num(6, 29) = 28
    await test_case(6, 29, 28)
    
    # Test case 6: choose_num(27, 10) = -1 (x > y)
    await test_case(27, 10, 0xFFFF)
    
    # Test case 7: choose_num(7, 7) = -1 (7 is odd)
    await test_case(7, 7, 0xFFFF)
    
    # Test case 8: choose_num(546, 546) = 546 (546 is even)
    await test_case(546, 546, 546)
    
    # Edge case: x = 0, y = 1 (smallest range)
    await test_case(0, 1, 0)
    
    # Edge case: both odd, result is even in between
    await test_case(1, 3, 2)
    
    # Edge case: x = y, both even
    await test_case(100, 100, 100)
    
    # Edge case: x = y, both odd
    await test_case(101, 101, 0xFFFF)
    
    # Edge case: large numbers
    await test_case(65534, 65535, 65534)
    
    print("
All tests passed!")
