import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure
import random

# Helper to convert float to Q16.16 fixed point
def float_to_q16_16(value):
    return int(value * 65536)

# Helper to encode grade string to 24-bit hex
def encode_grade(grade):
    # Pad to 3 chars with spaces
    grade = grade.ljust(3, ' ')
    # Convert to bytes (big endian)
    b = grade.encode('ascii')
    return (b[0] << 16) | (b[1] << 8) | b[2]

# Helper to check if value is defined
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_grade_converter(dut):
    """Test the grade converter module with various GPA values."""
    
    # Test cases: (gpa0, gpa1, gpa2, gpa3, expected_grade0, expected_grade1, expected_grade2, expected_grade3)
    test_cases = [
        (4.0, 3.0, 1.7, 2.0, 'A+', 'B+', 'C-', 'C+'),
        (1.2, 0.0, 0.5, 3.5, 'D+', 'E', 'D-', 'A-'),
        (3.8, 2.8, 1.5, 0.3, 'A', 'B', 'C-', 'D-'),
        (3.7, 2.3, 1.0, 0.7, 'A', 'B-', 'D+', 'D'),
        (3.2, 2.2, 1.4, 0.1, 'B+', 'C+', 'C-', 'D-'),
    ]

    dut._log.info(f"Running {len(test_cases)} test cases")
    passed = 0

    for i, (g0, g1, g2, g3, exp0, exp1, exp2, exp3) in enumerate(test_cases):
        # Convert floats to Q16.16
        val0 = float_to_q16_16(g0)
        val1 = float_to_q16_16(g1)
        val2 = float_to_q16_16(g2)
        val3 = float_to_q16_16(g3)

        # Assign inputs
        dut.gpa0.value = val0
        dut.gpa1.value = val1
        dut.gpa2.value = val2
        dut.gpa3.value = val3

        # Wait for combinational logic to settle
        await Timer(50, units='ns')

        # Check outputs
        # We need to check all 4 outputs
        outputs = []
        errors = []

        # Check grade0
        if not is_value_defined(dut.grade0.value):
            errors.append(f"grade0 is undefined (X/Z)")
        else:
            val = int(dut.grade0.value)
            expected = encode_grade(exp0)
            if val != expected:
                errors.append(f"grade0: expected {exp0} ({hex(expected)}), got {val:#x}")
            else:
                outputs.append(exp0)

        # Check grade1
        if not is_value_defined(dut.grade1.value):
            errors.append(f"grade1 is undefined (X/Z)")
        else:
            val = int(dut.grade1.value)
            expected = encode_grade(exp1)
            if val != expected:
                errors.append(f"grade1: expected {exp1} ({hex(expected)}), got {val:#x}")
            else:
                outputs.append(exp1)

        # Check grade2
        if not is_value_defined(dut.grade2.value):
            errors.append(f"grade2 is undefined (X/Z)")
        else:
            val = int(dut.grade2.value)
            expected = encode_grade(exp2)
            if val != expected:
                errors.append(f"grade2: expected {exp2} ({hex(expected)}), got {val:#x}")
            else:
                outputs.append(exp2)

        # Check grade3
        if not is_value_defined(dut.grade3.value):
            errors.append(f"grade3 is undefined (X/Z)")
        else:
            val = int(dut.grade3.value)
            expected = encode_grade(exp3)
            if val != expected:
                errors.append(f"grade3: expected {exp3} ({hex(expected)}), got {val:#x}")
            else:
                outputs.append(exp3)

        if errors:
            dut._log.error(f"Test case {i} ({g0}, {g1}, {g2}, {g3}) failed:")
            for err in errors:
                dut._log.error(f"  {err}")
            raise TestFailure(f"Test case {i} failed")
        else:
            dut._log.info(f"Test case {i}: {g0}, {g1}, {g2}, {g3} -> {outputs} [OK]")
            passed += 1

    dut._log.info(f"Summary: {passed}/{len(test_cases)} tests passed")
    if passed != len(test_cases):
        raise TestFailure(f"Only {passed}/{len(test_cases)} tests passed")
