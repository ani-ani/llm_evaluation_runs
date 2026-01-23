import cocotb
from cocotb.triggers import Timer

# Helper function to convert tuple to individual input values
def set_tuple_inputs(dut, tuple_name, values):
    """Set inputs for a tuple from a list of 4 values"""
    for i, val in enumerate(values):
        setattr(dut, f"{tuple_name}_{i}", val)

def get_tuple_results(dut):
    """Get result values as a tuple from outputs"""
    return tuple(int(getattr(dut, f"result_{i}")) for i in range(4))

@cocotb.test()
async def test_tuple_xor_basic(dut):
    """Test basic XOR operation on tuple elements"""
    # Test case 1: (10, 4, 6, 9) ^ (5, 2, 3, 3) = (15, 6, 5, 10)
    set_tuple_inputs(dut, "tuple1", [10, 4, 6, 9])
    set_tuple_inputs(dut, "tuple2", [5, 2, 3, 3])
    
    await Timer(1, units='ns')
    
    result = get_tuple_results(dut)
    expected = (15, 6, 5, 10)
    
    assert result == expected, f"Test 1 failed: expected {expected}, got {result}"
    print(f"Test 1 passed: {result}")

@cocotb.test()
async def test_tuple_xor_case2(dut):
    """Test second test case"""
    # Test case 2: (11, 5, 7, 10) ^ (6, 3, 4, 4) = (13, 6, 3, 14)
    set_tuple_inputs(dut, "tuple1", [11, 5, 7, 10])
    set_tuple_inputs(dut, "tuple2", [6, 3, 4, 4])
    
    await Timer(1, units='ns')
    
    result = get_tuple_results(dut)
    expected = (13, 6, 3, 14)
    
    assert result == expected, f"Test 2 failed: expected {expected}, got {result}"
    print(f"Test 2 passed: {result}")

@cocotb.test()
async def test_tuple_xor_case3(dut):
    """Test third test case"""
    # Test case 3: (12, 6, 8, 11) ^ (7, 4, 5, 6) = (11, 2, 13, 13)
    set_tuple_inputs(dut, "tuple1", [12, 6, 8, 11])
    set_tuple_inputs(dut, "tuple2", [7, 4, 5, 6])
    
    await Timer(1, units='ns')
    
    result = get_tuple_results(dut)
    expected = (11, 2, 13, 13)
    
    assert result == expected, f"Test 3 failed: expected {expected}, got {result}"
    print(f"Test 3 passed: {result}")

@cocotb.test()
async def test_tuple_xor_zeros(dut):
    """Test edge case with zeros"""
    set_tuple_inputs(dut, "tuple1", [0, 0, 0, 0])
    set_tuple_inputs(dut, "tuple2", [0, 0, 0, 0])
    
    await Timer(1, units='ns')
    
    result = get_tuple_results(dut)
    expected = (0, 0, 0, 0)
    
    assert result == expected, f"Zeros test failed: expected {expected}, got {result}"
    print(f"Zeros test passed: {result}")

@cocotb.test()
async def test_tuple_xor_max(dut):
    """Test edge case with max values (255)"""
    set_tuple_inputs(dut, "tuple1", [255, 255, 255, 255])
    set_tuple_inputs(dut, "tuple2", [255, 255, 255, 255])
    
    await Timer(1, units='ns')
    
    result = get_tuple_results(dut)
    expected = (0, 0, 0, 0)
    
    assert result == expected, f"Max values test failed: expected {expected}, got {result}"
    print(f"Max values test passed: {result}")

@cocotb.test()
async def test_tuple_xor_powers_of_2(dut):
    """Test with powers of 2"""
    set_tuple_inputs(dut, "tuple1", [1, 2, 4, 8])
    set_tuple_inputs(dut, "tuple2", [1, 3, 5, 9])
    
    await Timer(1, units='ns')
    
    result = get_tuple_results(dut)
    expected = (0, 1, 1, 1)  # 1^1=0, 2^3=1, 4^5=1, 8^9=1
    
    assert result == expected, f"Powers of 2 test failed: expected {expected}, got {result}"
    print(f"Powers of 2 test passed: {result}")

if __name__ == "__main__":
    # Run all tests and print summary
    import sys
    from cocotb.runner import get_runner
    
    sim = get_runner("icarus")
    results = sim.test()
    
    passed = sum(1 for r in results if r['passed'])
    total = len(results)
    
    print(f"
{'='*50}")
    print(f"SUMMARY: {passed}/{total} tests passed")
    print(f"{'='*50}")
    
    sys.exit(0 if passed == total else 1)