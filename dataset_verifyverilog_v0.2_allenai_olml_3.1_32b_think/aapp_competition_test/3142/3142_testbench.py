import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def bcd_to_int(bcd):
    """Convert 6-digit BCD to integer"""
    result = 0
    for i in range(6):
        digit = (bcd >> (i*4)) & 0xF
        result += digit * (10 ** i)
    return result

def int_to_bcd(num):
    """Convert integer to 6-digit BCD"""
    bcd = 0
    for i in range(6):
        digit = (num // (10 ** i)) % 10
        bcd |= digit << (i * 4)
    return bcd

def count_and_min_python(A, B, S):
    """Python reference for verification"""
    count = 0
    min_val = None
    for num in range(A, B + 1):
        digit_sum = sum(int(d) for d in str(num))
        if digit_sum == S:
            count += 1
            if min_val is None or num < min_val:
                min_val = num
    return count, min_val if min_val is not None else 0

@cocotb.test()
async def test_digit_sum_counter(dut):
    """Test digit_sum_counter with various test cases"""
    
    test_cases = [
        # (A, B, S, expected_count, expected_min)
        (1, 9, 5, 1, 5),
        (1, 100, 10, 9, 19),
        (11111, 99999, 24, 5445, 11499),
        (1, 1000, 1, 1, 1),
        (50, 60, 5, 1, 55),
        (999990, 999999, 45, 1, 999990),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (A, B, S, exp_count, exp_min) in enumerate(test_cases):
        # Convert to BCD
        A_bcd = int_to_bcd(A)
        B_bcd = int_to_bcd(B)
        
        # Drive inputs
        dut.A_digits.value = A_bcd
        dut.B_digits.value = B_bcd
        dut.S_value.value = S
        
        # Wait for combinational logic
        await Timer(100, units='ns')
        
        # Read outputs
        count = dut.count.value
        min_bcd = dut.min_number.value
        min_int = bcd_to_int(min_bcd)
        
        # Verify
        if count != exp_count:
            raise TestFailure(f"Test {i}: count mismatch. Expected {exp_count}, got {count}")
        if min_int != exp_min:
            raise TestFailure(f"Test {i}: min mismatch. Expected {exp_min}, got {min_int}")
        
        print(f"Test {i}: A={A}, B={B}, S={S} -> count={count}, min={min_int} ✓")
        passed += 1
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total
