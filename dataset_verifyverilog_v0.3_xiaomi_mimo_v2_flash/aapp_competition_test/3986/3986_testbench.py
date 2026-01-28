import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

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

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_lex_string(dut):
    """Test lex_string module with scaled inputs."""
    
    # Test cases: (n, k, expected_string) or (n, k, None) for invalid
    test_cases = [
        (7, 4, "ababacd"),
        (4, 7, None),
        (1, 1, "a"),
        (2, 2, "ab"),
        (3, 3, "abc"),
        (4, 2, "abab"),
        (5, 3, "ababc"),
        (10, 5, "abababacde"),
        (47, 2, "ab" * 23 + "a"),
        (10, 7, "ababacdefg"),
        (26, 8, "abababababababababab" + "cdefgh"),
        (8, 8, "abcdefgh"),
        (64, 8, "ab" * 29 + "cdefgh"),
        (1, 2, None),
        (0, 1, None),
    ]
    
    passed = 0
    failed = 0
    
    for n, k, expected in test_cases:
        dut.n.value = n
        dut.k.value = k
        await Timer(10, units='ns')  # Propagation delay
        
        if not is_value_defined(dut.valid.value):
            dut._log.error(f"Test (n={n},k={k}): valid signal undefined")
            failed += 1
            continue
            
        valid = int(dut.valid.value)
        
        if expected is None:
            if valid == 1:
                dut._log.error(f"Test (n={n},k={k}): Expected invalid, got valid")
                failed += 1
            else:
                dut._log.info(f"Test (n={n},k={k}): PASS (correctly invalid)")
                passed += 1
        else:
            if valid != 1:
                dut._log.error(f"Test (n={n},k={k}): Expected valid, got invalid")
                failed += 1
                continue
            
            # Extract string from 512-bit output
            data = int(dut.string_data.value)
            actual = ""
            for i in range(n):
                byte = (data >> (8 * i)) & 0xFF
                if byte == 0:
                    break
                actual += chr(byte)
            
            if actual == expected:
                dut._log.info(f"Test (n={n},k={k}): PASS (got '{actual}')")
                passed += 1
            else:
                dut._log.error(f"Test (n={n},k={k}): Expected '{expected}', got '{actual}'")
                failed += 1
    
    dut._log.info(f"\n{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")