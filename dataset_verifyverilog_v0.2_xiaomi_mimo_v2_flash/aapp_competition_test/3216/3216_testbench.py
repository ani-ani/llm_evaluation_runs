import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

def gcd(a, b):
    while b:
        a, b = b, a % b
    return a

def convert_repeating_decimal(int_part, frac_str, repeat_count):
    """Convert repeating decimal to fraction"""
    frac_digits = len(frac_str)
    
    # Parse as integers
    I = int_part
    F = int(frac_str)
    
    # Split into non-repeating and repeating parts
    non_rep_len = frac_digits - repeat_count
    
    if non_rep_len > 0:
        A_str = frac_str[:non_rep_len]
        B_str = frac_str[non_rep_len:]
    else:
        A_str = ""
        B_str = frac_str
    
    A = int(A_str) if A_str else 0
    B = int(B_str) if B_str else 0
    
    # Calculate powers of 10
    pow10_L = 10 ** frac_digits
    pow10_L_minus_K = 10 ** non_rep_len if non_rep_len > 0 else 1
    pow10_K = 10 ** repeat_count
    
    # Numerator = I * (10^L - 10^(L-K)) + A * (10^K - 1) + B
    num = I * (pow10_L - pow10_L_minus_K) + A * (pow10_K - 1) + B
    
    # Denominator = (10^L - 10^(L-K)) * (10^K - 1)
    den = (pow10_L - pow10_L_minus_K) * (pow10_K - 1)
    
    # Reduce
    g = gcd(num, den)
    return num // g, den // g

@cocotb.test()
async def test_repeating_decimal_converter(dut):
    """Test repeating decimal to fraction conversion"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (int_part, frac_str, repeat_count, expected_num, expected_den)
    test_cases = [
        (0, "142857", 6, 1, 7),      # 0.142857... = 1/7
        (1, "6", 1, 5, 3),            # 1.666... = 5/3
        (123, "456", 2, 61111, 495),  # 123.45656... = 61111/495
        (0, "3", 1, 1, 3),            # 0.333... = 1/3
        (2, "5", 1, 23, 9),           # 2.555... = 23/9
    ]
    
    passed = 0
    total = len(test_cases)
    
    for int_part, frac_str, repeat_count, exp_num, exp_den in test_cases:
        frac_digits = len(frac_str)
        frac_part_val = int(frac_str)
        
        # Calculate expected
        exp_num, exp_den = convert_repeating_decimal(int_part, frac_str, repeat_count)
        
        print(f"Test: {int_part}.{frac_str} (repeat {repeat_count})")
        print(f"  Expected: {exp_num}/{exp_den}")
        
        # Load inputs
        dut.decimal_int_part.value = int_part
        dut.decimal_frac_part.value = frac_part_val
        dut.frac_digits.value = frac_digits
        dut.repeat_count.value = repeat_count
        
        # Start computation
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 200 cycles)
        timeout = 200
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Timeout: computation did not complete for {int_part}.{frac_str}")
        
        # Read results
        num = int(dut.numerator.value)
        den = int(dut.denominator.value)
        
        print(f"  Got: {num}/{den}")
        
        # Verify
        if num == exp_num and den == exp_den:
            passed += 1
            print(f"  PASS")
        else:
            print(f"  FAIL")
            raise TestFailure(f"Mismatch: expected {exp_num}/{exp_den}, got {num}/{den}")
    
    print(f"
=== SUMMARY: {passed}/{total} tests passed ===")
    
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
