import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 4

# Helper functions


def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False


def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default


def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False


@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_divisibility_hack(dut):
    """Test divisibility hack checker with scaled-down test cases."""

    # Define test cases: (b, d, expected)
    # expected: 1 for yes, 0 for no
    test_cases = [
        (10, 11, 1),  # 10 mod 11 = 10, which is -1 mod 11? Actually, 10^5 ≡ -1 mod 11? Yes.
        (10, 7, 1),   # 10^3 ≡ -1 mod 7? Yes.
        (10, 3, 0),   # No m such that 10^m ≡ -1 mod 3
        (1, 2, 1),    # b=1, d=2: 1 is odd, so yes
        (2, 2, 0),    # b=2, d=2: 2 is even, so no
        (2, 3, 1),    # 2^1 ≡ -1 mod 3? Yes, 2 ≡ -1 mod 3
        (2, 5, 1),    # 2^2 ≡ -1 mod 5? 4 ≡ -1 mod 5, yes
        (2, 7, 0),    # Check: 2^3=8≡1 mod 7, not -1. No m exists? Actually, 2^3=1, 2^6=1, so no -1. So 0.
        (2, 11, 1),   # 2^5=32≡ -1 mod 11? 32 mod 11=10≡ -1, yes.
        (2, 13, 1),   # 2^6=64≡ -1 mod 13? 64 mod 13=12≡ -1, yes.
        (3, 5, 1),    # 3^2=9≡ -1 mod 5? 9 mod 5=4≡ -1, yes.
        (4, 3, 0),    # 4 mod 3=1, never -1, so no.
        (5, 3, 1),    # 5 mod 3=2≡ -1, so yes.
        (6, 7, 1),    # 6 mod 7=6≡ -1, so yes.
        (7, 13, 1),   # 7^6 mod 13: we computed earlier, yes.
        (8, 11, 1),   # 8 mod 11=8, not -1, but 8^5 mod 11? 8^2=64≡9, 8^4=81≡4, 8^5=32≡10≡ -1, yes.
        (9, 13, 0),   # 9 mod 13=9, not -1. 9^6 mod 13: 9^2=81≡3, 9^4=9, 9^6=27≡1, not -1. So 0.
        (10, 13, 0),  # 10 mod 13=10, not -1. 10^6 mod 13: 10^2=100≡9, 10^4=81≡3, 10^6=30≡4, not -1. So 0.
    ]

    passed = 0
    failed = 0

    for b_val, d_val, expected in test_cases:
        # Clamp values to 4 bits (though they are within range)
        b_val = b_val & 0xF
        d_val = d_val & 0xF

        # Assign inputs
        if has_signal(dut, 'b'):
            dut.b.value = b_val
        else:
            raise TestFailure("Signal 'b' not found")

        if has_signal(dut, 'd'):
            dut.d.value = d_val
        else:
            raise TestFailure("Signal 'd' not found")

        # Wait for combinational logic to settle
        await Timer(10, units='ns')

        # Read output
        if has_signal(dut, 'yes_no'):
            if not is_value_defined(dut.yes_no.value):
                raise TestFailure(f"Output yes_no is undefined for b={b_val}, d={d_val}")
            result = int(dut.yes_no.value)
        else:
            raise TestFailure("Signal 'yes_no' not found")

        # Check result
        if result != expected:
            failed += 1
            raise TestFailure(f"Test failed for b={b_val}, d={d_val}: expected {expected}, got {result}")
        else:
            passed += 1
            dut._log.info(f"PASS: b={b_val}, d={d_val} -> {result}")

    # Summary
    dut._log.info(f"\n{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")

    if failed > 0:
        raise TestFailure(f"{failed} tests failed")