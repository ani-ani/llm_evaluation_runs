import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_swap_numbers(dut):
    """Test that swap_numbers correctly exchanges two 16-bit values"""
    
    # Test case 1: 10 and 20
    dut.a.value = 10
    dut.b.value = 20
    await Timer(10, units='ns')
    assert dut.swapped_a.value == 20, f"Expected swapped_a=20, got {dut.swapped_a.value}"
    assert dut.swapped_b.value == 10, f"Expected swapped_b=10, got {dut.swapped_b.value}"
    print("Test 1 passed: 10, 20 -> 20, 10")
    
    # Test case 2: 15 and 17
    dut.a.value = 15
    dut.b.value = 17
    await Timer(10, units='ns')
    assert dut.swapped_a.value == 17, f"Expected swapped_a=17, got {dut.swapped_a.value}"
    assert dut.swapped_b.value == 15, f"Expected swapped_b=15, got {dut.swapped_b.value}"
    print("Test 2 passed: 15, 17 -> 17, 15")
    
    # Test case 3: 100 and 200
    dut.a.value = 100
    dut.b.value = 200
    await Timer(10, units='ns')
    assert dut.swapped_a.value == 200, f"Expected swapped_a=200, got {dut.swapped_a.value}"
    assert dut.swapped_b.value == 100, f"Expected swapped_b=100, got {dut.swapped_b.value}"
    print("Test 3 passed: 100, 200 -> 200, 100")
    
    # Additional edge cases
    # Zero values
    dut.a.value = 0
    dut.b.value = 0
    await Timer(10, units='ns')
    assert dut.swapped_a.value == 0 and dut.swapped_b.value == 0
    print("Edge case 1 passed: 0, 0 -> 0, 0")
    
    # Max values
    dut.a.value = 65535  # 16-bit max
    dut.b.value = 0
    await Timer(10, units='ns')
    assert dut.swapped_a.value == 0 and dut.swapped_b.value == 65535
    print("Edge case 2 passed: 65535, 0 -> 0, 65535")
    
    print("All 5/5 tests passed!")