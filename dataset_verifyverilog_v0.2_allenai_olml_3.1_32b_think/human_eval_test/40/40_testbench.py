import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_triples_sum_to_zero(dut):
    """Test triples_sum_to_zero module with various test cases"""
    
    # Helper function to convert signed decimal to 4-bit hex
    def to_signed_4bit(n):
        if n < 0:
            return n & 0xF
        else:
            return n & 0xF
    
    # Test cases adapted from original (only first 8 elements used)
    test_cases = [
        # (list, expected_result)
        ([1, 3, 5, 0], False),
        ([1, 3, 5, -1], False),
        ([1, 3, -2, 1], True),
        ([1, 2, 3, 7], False),
        ([1, 2, 5, 7], False),
        ([2, 4, -5, 3, 9, 7], True),
        ([1], False),
        ([1, 3, 5, -100], False),  # -100 won't fit in 4-bit, will be truncated
        ([100, 3, 5, -100], False),  # 100 and -100 truncated
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (test_list, expected) in enumerate(test_cases):
        # Extract first 8 elements and pad with 0
        inputs = [0] * 8
        count = min(len(test_list), 8)
        for idx in range(count):
            inputs[idx] = to_signed_4bit(test_list[idx])
        
        # Set inputs
        dut.num0.value = inputs[0]
        dut.num1.value = inputs[1]
        dut.num2.value = inputs[2]
        dut.num3.value = inputs[3]
        dut.num4.value = inputs[4]
        dut.num5.value = inputs[5]
        dut.num6.value = inputs[6]
        dut.num7.value = inputs[7]
        dut.count.value = count
        
        # Wait for combinational logic
        await Timer(10, units='ns')
        
        # Read result
        result = int(dut.result.value)
        expected_int = 1 if expected else 0
        
        # Check assertion
        try:
            assert result == expected_int, f"Test {i+1} failed: input={test_list}, expected={expected_int}, got={result}"
            passed += 1
            print(f"Test {i+1} PASSED: {test_list} -> {'True' if result else 'False'}")
        except AssertionError as e:
            print(f"Test {i+1} FAILED: {e}")
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
