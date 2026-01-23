import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def to_int(value):
    # Helper to handle python integer to verilog logic
    return int(value)

def to_bin(value, width):
    # Helper for binary representation if needed
    return format(value & ((1<<width)-1), f'0{width}b')

@cocotb.test()
async def test_table_tennis_sets(dut):
    """Test table tennis sets logic"""
    
    # Test cases: (k, a, b, expected_result)
    # Note: 65535 represents -1 (impossible)
    test_cases = [
        (11, 11, 5, 1),      # Valid: Misha won 1 set (11), Vanya got 5 (from a lost set). Misha must have won the set Vanya lost.
        (11, 2, 3, 65535),   # Impossible: Total points < k, but input says a+b>0. Remnants exist but no full wins.
        (1, 5, 9, 14),       # k=1, a=5, b=9. Sets: 14 total sets.
        (2, 3, 3, 2),        # 2 sets: (2,1) and (1,2) or similar.
        (5, 6, 0, 1),        # Misha: 1 win (5 points), 1 leftover (valid). Vanya: 0 wins, 0 left.
        (10, 0, 13, 65535),  # Impossible: a=0, b=13. Vanya has 13 points. Since k=10, Vanya has 1 full win (10 points) and 3 left. The 3 left must come from a set Misha won. But Misha has 0 points.
        (2, 11, 0, 65535),   # Impossible: b=0, a=11. Misha has 5 wins (10 points) and 1 left. The 1 left requires Vanya to have a win. Vanya has 0.
        (2, 1, 0, 65535),    # Impossible: Total points 1, less than k=2.
        (10, 11, 12, 2),     # Misha: 1 win, 1 rem. Vanya: 1 win, 2 rem. Valid. Total 2 sets.
        (255, 255, 255, 2),  # Max values check. 1 win each.
        (10000, 5000, 10000, 65535), # Impossible: Misha < k, Vanya wins but Misha has 5000. Vanya's leftover (0) is fine, but Misha has no wins to account for his 5000.
    ]

    passed = 0
    total = len(test_cases)

    for k_in, a_in, b_in, expected in test_cases:
        # Skip if inputs exceed 16-bit range (as per module spec)
        if k_in > 65535 or a_in > 65535 or b_in > 65535:
            print(f"Skipping case ({k_in}, {a_in}, {b_in}) - exceeds 16-bit range")
            total -= 1
            continue

        dut.k.value = k_in
        dut.a.value = a_in
        dut.b.value = b_in
        
        # Combinational logic, add small delay
        await Timer(10, units='ns')
        
        result = int(dut.result.value)
        
        # Handle -1 representation
        actual_result = result
        
        if actual_result != expected:
            # If expected is 65535 (our -1), check if result is 65535
            if expected == 65535 and actual_result == 65535:
                passed += 1
                print(f"PASS: k={k_in}, a={a_in}, b={b_in} -> Result={actual_result} (Correctly Impossible)")
            else:
                print(f"FAIL: k={k_in}, a={a_in}, b={b_in} -> Expected {expected}, Got {actual_result}")
                # Don't raise exception to allow running all tests
        else:
            passed += 1
            print(f"PASS: k={k_in}, a={a_in}, b={b_in} -> Result={actual_result}")

    print(f"
Summary: {passed}/{total} tests passed")
    if passed < total:
        raise TestFailure(f"{total - passed} tests failed")
