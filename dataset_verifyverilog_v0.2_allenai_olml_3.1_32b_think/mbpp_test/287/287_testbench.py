import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

@cocotb.test()
async def test_sum_even_squares(dut):
    """Test sum of squares of first n even numbers"""
    
    # Test case 1: n = 2
    # Expected: 2*2^2 + 4*4^2 = 8 + 16 = 20
    # Formula: 2*2*(2+1)*(2*2+1)/3 = 4*3*5/3 = 20
    dut.n.value = 2
    await Timer(10, units='ns')
    assert dut.result.value.integer == 20, f"Test 1 failed: expected 20, got {dut.result.value.integer}"
    print(f"Test 1 passed: n=2, result={dut.result.value.integer}")
    
    # Test case 2: n = 3
    # Expected: 8 + 16 + 36 = 56
    # Formula: 2*3*(3+1)*(2*3+1)/3 = 6*4*7/3 = 168/3 = 56
    dut.n.value = 3
    await Timer(10, units='ns')
    assert dut.result.value.integer == 56, f"Test 2 failed: expected 56, got {dut.result.value.integer}"
    print(f"Test 2 passed: n=3, result={dut.result.value.integer}")
    
    # Test case 3: n = 4
    # Expected: 8 + 16 + 36 + 64 = 120
    # Formula: 2*4*(4+1)*(2*4+1)/3 = 8*5*9/3 = 360/3 = 120
    dut.n.value = 4
    await Timer(10, units='ns')
    assert dut.result.value.integer == 120, f"Test 3 failed: expected 120, got {dut.result.value.integer}"
    print(f"Test 3 passed: n=4, result={dut.result.value.integer}")
    
    # Test case 4: Edge case n = 0
    # Expected: 0 (sum of zero terms)
    dut.n.value = 0
    await Timer(10, units='ns')
    assert dut.result.value.integer == 0, f"Test 4 failed: expected 0, got {dut.result.value.integer}"
    print(f"Test 4 passed: n=0, result={dut.result.value.integer}")
    
    # Test case 5: Edge case n = 1
    # Expected: 2*1^2 = 2
    # Formula: 2*1*(1+1)*(2*1+1)/3 = 2*2*3/3 = 2
    dut.n.value = 1
    await Timer(10, units='ns')
    assert dut.result.value.integer == 2, f"Test 5 failed: expected 2, got {dut.result.value.integer}"
    print(f"Test 5 passed: n=1, result={dut.result.value.integer}")
    
    # Test case 6: Larger value n = 10
    # Expected: 8 + 16 + 36 + 64 + 100 + 144 + 196 + 256 + 324 + 400 = 1544
    dut.n.value = 10
    await Timer(10, units='ns')
    expected = 1544
    assert dut.result.value.integer == expected, f"Test 6 failed: expected {expected}, got {dut.result.value.integer}"
    print(f"Test 6 passed: n=10, result={dut.result.value.integer}")
    
    print("
=== Summary ===")
    print("6/6 tests passed")
