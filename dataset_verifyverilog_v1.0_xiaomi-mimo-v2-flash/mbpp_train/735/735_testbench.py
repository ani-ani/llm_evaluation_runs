import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_toggle_middle_bits(dut):
    # Combinational module (no clock/reset)
    
    # Define test cases: (input, expected_output, description)
    test_cases = [
        (9, 15, "9 (0b1001) → 15 (0b1111)"),
        (10, 12, "10 (0b1010) → 12 (0b1100)"),
        (11, 13, "11 (0b1011) → 13 (0b1101)"),
        (129, 127, "0b1000001 → 0b1111111"),
        (77, 115, "0b1001101 → 0b1110011"),
        (0, 0, "0 → 0 (edge case)"),
        (1, 1, "1 → 1 (edge case, no middle bits)"),
        (255, 255, "All bits set → unchanged")
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Clamp input to 16 bits
            n_clamped = clamp_to_width(n, 16)
            
            # Assign input
            dut.n.value = n_clamped
            
            # Wait for combinational propagation
            await Timer(100, units='ns')
            
            # Check if result signal exists and is defined
            if not has_signal(dut, 'result'):
                raise TestFailure("Result signal not found")
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal is undefined (X/Z)")
            
            # Read and clamp result
            result = int(dut.result.value)
            result &= ((1 << 16) - 1)  # Ensure 16-bit
            
            # Verify result
            if result != expected:
                raise TestFailure(f"Expected {expected} (0x{expected:04X}), got {result} (0x{result:04X})")
            
            # Also verify done signal if present
            if has_signal(dut, 'done'):
                if not is_value_defined(dut.done.value):
                    raise TestFailure("Done signal is undefined")
                if int(dut.done.value) != 1:
                    raise TestFailure(f"Done should be 1, got {dut.done.value}")
            
            passed += 1
            cocotb.log.info(f"  PASS: result = {result} (0x{result:04X})")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\nTest Summary: {passed} passed, {failed} failed")
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")
