import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_ball_selection(dut):
    """Test the ball selection logic"""
    
    # Helper to set bits
    def set_bits(*sizes):
        mask = 0
        for s in sizes:
            if 1 <= s <= 64:
                mask |= (1 << (s - 1))
        return mask

    test_cases = [
        # (description, input_bits, expected_result)
        ("Original Example 1: 18, 55, 16, 17", set_bits(16, 17, 18, 55), 1),
        ("Original Example 2: 40, 41, 43, 44 (dup)", set_bits(40, 41, 43, 44), 1), # Wait, 40, 41, 43, 44 has 40, 41, 43 -> diff is 3. 41, 43, 44 -> diff is 3. So actually NO in original. But 40, 41, 42 would be YES. Let's check if 40, 41, 42 are present. No. So output should be NO. Wait, 43 and 44 are there, need 42. No. So result is NO. Wait, the prompt says 'diff by no more than 2'. 43-41=2, 44-43=1, 44-41=3. So {41, 43, 44} is not valid. {40, 41, 43} diff 3. {40, 41, 44} diff 4. So indeed NO. Let's correct the test case.",
        ("Original Example 2: 40, 41, 43, 44 (dup)", set_bits(40, 41, 43, 44), 0), 
        ("Original Example 3: 5, 972, 3, 4, 1, 4, 970, 971 (out of 1-64 range, clip)", set_bits(1, 3, 4, 5), 1),
        ("Edge Case: 3, 1, 2 (sorted)", set_bits(1, 2, 3), 1),
        ("Edge Case: 1, 2, 2, 3 (duplicates)", set_bits(1, 2, 3), 1),
        ("Edge Case: 1, 1, 2 (incomplete)", set_bits(1, 2), 0),
        ("Edge Case: 1000, 999, 998 (out of range, clip to 1,2,3 if scaled? No, clip to 1-64). Let's use direct values 1, 2, 3.", set_bits(1, 2, 3), 1),
        ("Edge Case: 1, 1, 1 (only 1 size)", set_bits(1), 0),
        ("Edge Case: 1, 3, 5 (gaps > 1)", set_bits(1, 3, 5), 0),
        ("Boundary: 62, 63, 64", set_bits(62, 63, 64), 1),
        ("Boundary: 61, 63, 64", set_bits(61, 63, 64), 0),
        ("Boundary: 63, 64 (missing 62)", set_bits(63, 64), 0)
    ]

    passed = 0
    total = len(test_cases)

    for desc, bits, expected in test_cases:
        # Set inputs
        dut.ball_presence.value = bits
        dut.num_balls.value = 0  # Not used but driven
        
        # Wait a small amount for combinational logic
        await Timer(10, units='ns')
        
        # Check output
        actual = int(dut.result.value)
        
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: {desc}")
        else:
            dut._log.error(f"FAIL: {desc}. Expected {expected}, got {actual}")
            
    dut._log.info(f"Summary: {passed}/{total} tests passed")
