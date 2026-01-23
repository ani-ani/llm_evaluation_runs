import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock
import random

def calculate_max_product(arr):
    """Reference function for max product pair"""
    if len(arr) < 2:
        return (0, 0)
    
    max_prod = arr[0] * arr[1]
    pair = (arr[0], arr[1])
    
    for i in range(len(arr)):
        for j in range(i + 1, len(arr)):
            prod = arr[i] * arr[j]
            if prod > max_prod:
                max_prod = prod
                pair = (arr[i], arr[j])
    
    return pair

@cocotb.test()
async def test_max_product_basic(dut):
    """Test basic functionality with positive numbers"""
    dut.data_in.value = [1, 2, 3, 4, 7, 0, 8, 4]
    await Timer(10, units='ns')
    
    result_a = int(dut.value_a)
    result_b = int(dut.value_b)
    
    # Signed conversion
    if result_a >= 2**15:
        result_a -= 2**16
    if result_b >= 2**15:
        result_b -= 2**16
    
    print(f"Test 1: Input: [1,2,3,4,7,0,8,4]")
    print(f"  Expected: (7,8)")
    print(f"  Got: ({result_a},{result_b})")
    
    # Both orders acceptable
    assert (result_a == 7 and result_b == 8) or (result_a == 8 and result_b == 7), \
        f"Expected (7,8) or (8,7), got ({result_a},{result_b})"

@cocotb.test()
async def test_max_product_negative(dut):
    """Test with negative numbers - two negatives give positive product"""
    dut.data_in.value = [0, -1, -2, -4, 5, 0, -6, 0]
    await Timer(10, units='ns')
    
    result_a = int(dut.value_a)
    result_b = int(dut.value_b)
    
    # Signed conversion
    if result_a >= 2**15:
        result_a -= 2**16
    if result_b >= 2**15:
        result_b -= 2**16
    
    print(f"Test 2: Input: [0,-1,-2,-4,5,0,-6,0]")
    print(f"  Expected: (-4,-6) product=24")
    print(f"  Got: ({result_a},{result_b}) product={result_a*result_b}")
    
    # Should get -4 and -6 (product=24)
    # Compare to 5 and 0 = 0, or 5 and -1 = -5
    assert (result_a == -4 and result_b == -6) or (result_a == -6 and result_b == -4), \
        f"Expected (-4,-6) or (-6,-4), got ({result_a},{result_b})"

@cocotb.test()
async def test_max_product_small_positives(dut):
    """Test with small array of positive numbers"""
    dut.data_in.value = [1, 2, 3, 0, 0, 0, 0, 0]
    await Timer(10, units='ns')
    
    result_a = int(dut.value_a)
    result_b = int(dut.value_b)
    
    if result_a >= 2**15:
        result_a -= 2**16
    if result_b >= 2**15:
        result_b -= 2**16
    
    print(f"Test 3: Input: [1,2,3,0,0,0,0,0]")
    print(f"  Expected: (2,3)")
    print(f"  Got: ({result_a},{result_b})")
    
    assert (result_a == 2 and result_b == 3) or (result_a == 3 and result_b == 2), \
        f"Expected (2,3) or (3,2), got ({result_a},{result_b})"

@cocotb.test()
async def test_max_product_all_negative(dut):
    """Test with all negative numbers - should pick two with smallest magnitude (closest to zero)"""
    dut.data_in.value = [-5, -4, -3, 0, 0, 0, 0, 0]
    await Timer(10, units='ns')
    
    result_a = int(dut.value_a)
    result_b = int(dut.value_b)
    
    if result_a >= 2**15:
        result_a -= 2**16
    if result_b >= 2**15:
        result_b -= 2**16
    
    print(f"Test 4: Input: [-5,-4,-3,0,0,0,0,0]")
    print(f"  Expected: (-4,-3) product=12")
    print(f"  Got: ({result_a},{result_b}) product={result_a*result_b}")
    
    # Should get -4 and -3 (product=12)
    assert (result_a == -4 and result_b == -3) or (result_a == -3 and result_b == -4), \
        f"Expected (-4,-3) or (-3,-4), got ({result_a},{result_b})"

@cocotb.test()
async def test_max_product_mixed_negative_positive(dut):
    """Test with mixed numbers where two negatives beat positives"""
    dut.data_in.value = [-10, -9, 2, 3, 0, 0, 0, 0]
    await Timer(10, units='ns')
    
    result_a = int(dut.value_a)
    result_b = int(dut.value_b)
    
    if result_a >= 2**15:
        result_a -= 2**16
    if result_b >= 2**15:
        result_b -= 2**16
    
    print(f"Test 5: Input: [-10,-9,2,3,0,0,0,0]")
    print(f"  Expected: (-10,-9) product=90")
    print(f"  Got: ({result_a},{result_b}) product={result_a*result_b}")
    
    # -10 * -9 = 90 vs 2 * 3 = 6, so should pick -10 and -9
    assert (result_a == -10 and result_b == -9) or (result_a == -9 and result_b == -10), \
        f"Expected (-10,-9) or (-9,-10), got ({result_a},{result_b})"

@cocotb.test()
async def test_max_product_single_value_array(dut):
    """Edge case: array effectively has only 2 non-zero values"""
    dut.data_in.value = [5, 8, 0, 0, 0, 0, 0, 0]
    await Timer(10, units='ns')
    
    result_a = int(dut.value_a)
    result_b = int(dut.value_b)
    
    if result_a >= 2**15:
        result_a -= 2**16
    if result_b >= 2**15:
        result_b -= 2**16
    
    print(f"Test 6: Input: [5,8,0,0,0,0,0,0]")
    print(f"  Expected: (5,8)")
    print(f"  Got: ({result_a},{result_b})")
    
    assert (result_a == 5 and result_b == 8) or (result_a == 8 and result_b == 5), \
        f"Expected (5,8) or (8,5), got ({result_a},{result_b})"

@cocotb.test()
async def test_max_product_large_values(dut):
    """Test with values near 16-bit limits"""
    # Using 32767 and 32766 as largest 16-bit positives
    # Using -32768 and -32767 as most negative
    dut.data_in.value = [32767, 32766, -32768, -32767, 0, 0, 0, 0]
    await Timer(10, units='ns')
    
    result_a = int(dut.value_a)
    result_b = int(dut.value_b)
    
    if result_a >= 2**15:
        result_a -= 2**16
    if result_b >= 2**15:
        result_b -= 2**16
    
    print(f"Test 7: Input: [32767,32766,-32768,-32767,0,0,0,0]")
    product = result_a * result_b
    print(f"  Got: ({result_a},{result_b}) product={product}")
    
    # Both products should be positive
    assert product >= 0, f"Product should be non-negative, got {product}"

print("
=== Test Summary ===")
print("All tests defined. Run with: pytest -v test_max_product.py")