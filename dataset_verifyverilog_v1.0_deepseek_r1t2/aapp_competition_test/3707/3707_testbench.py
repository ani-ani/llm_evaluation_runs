import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_oven_decision(dut):
    """Test the oven decision logic with all provided test cases."""
    
    # Test cases: (n, t, k, d, expected)
    test_cases = [
        (8, 6, 4, 5, 1),
        (8, 6, 4, 6, 0),
        (10, 3, 11, 4, 0),
        (4, 2, 1, 4, 1),
        (28, 17, 16, 26, 0),
        (60, 69, 9, 438, 0),
        (599, 97, 54, 992, 1),
        (11, 22, 18, 17, 0),
        (1, 13, 22, 11, 0),
        (1, 1, 1, 1, 0),
        (3, 1, 1, 1, 1),
        (1000, 1000, 1000, 1000, 0),
        (1000, 1000, 1, 1, 1),
        (1000, 1000, 1, 400, 1),
        (1000, 1000, 1, 1000, 1),
        (1000, 1000, 1, 999, 1),
        (53, 11, 3, 166, 1),
        (313, 2, 3, 385, 0),
        (214, 9, 9, 412, 0),
        (349, 9, 5, 268, 1),
        (611, 16, 8, 153, 1),
        (877, 13, 3, 191, 1),
        (340, 9, 9, 10, 1),
        (31, 8, 2, 205, 0),
        (519, 3, 2, 148, 1),
        (882, 2, 21, 219, 0),
        (982, 13, 5, 198, 1),
        (428, 13, 6, 272, 1),
        (436, 16, 14, 26, 1),
        (628, 10, 9, 386, 1),
        (77, 33, 18, 31, 1),
        (527, 36, 4, 8, 1),
        (128, 18, 2, 169, 1),
        (904, 4, 2, 288, 1),
        (986, 4, 3, 25, 1),
        (134, 8, 22, 162, 0),
        (942, 42, 3, 69, 1),
        (894, 4, 9, 4, 1),
        (953, 8, 10, 312, 1),
        (43, 8, 1, 121, 1),
        (12, 13, 19, 273, 0),
        (204, 45, 10, 871, 1),
        (342, 69, 50, 425, 0),
        (982, 93, 99, 875, 0),
        (283, 21, 39, 132, 0),
        (1000, 45, 83, 686, 0),
        (246, 69, 36, 432, 0),
        (607, 93, 76, 689, 0),
        (503, 21, 24, 435, 0),
        (1000, 45, 65, 989, 0),
        (30, 21, 2, 250, 1),
        (1000, 49, 50, 995, 0),
        (383, 69, 95, 253, 1),
        (393, 98, 35, 999, 1),
        (1000, 22, 79, 552, 0),
        (268, 294, 268, 154, 0),
        (963, 465, 706, 146, 0),
        (304, 635, 304, 257, 0),
        (4, 2, 1, 6, 0),
        (1, 51, 10, 50, 0),
        (5, 5, 4, 4, 0),
        (3, 2, 1, 1, 1),
        (3, 4, 3, 3, 0),
        (7, 3, 4, 1, 1),
        (101, 10, 1, 1000, 0),
        (5, 1, 1, 1, 1),
        (5, 10, 5, 5, 0),
        (19, 1, 7, 1, 1),
        (763, 572, 745, 262, 0),
        (1, 2, 1, 1, 0),
        (5, 1, 1, 3, 1),
        (170, 725, 479, 359, 0),
        (6, 2, 1, 7, 0),
        (6, 2, 5, 1, 0),
        (1, 2, 2, 1, 0),
        (24, 2, 8, 3, 1),
        (7, 3, 3, 3, 0),
        (5, 2, 2, 2, 0),
        (3, 2, 1, 2, 1),
        (1000, 2, 200, 8, 1),
        (3, 100, 2, 100, 0),
        (2, 999, 1, 1000, 0),
        (2, 1, 1, 1, 1),
        (2, 3, 5, 1, 0),
        (100, 1, 5, 1, 1),
        (7, 2, 3, 3, 0),
        (4, 1, 1, 3, 1),
        (3, 2, 2, 1, 0),
        (1, 1, 1, 2, 0),
        (91, 8, 7, 13, 1),
        (3, 1, 2, 1, 1),
        (5, 3, 2, 3, 0),
        (9, 6, 6, 3, 1)
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, t, k, d, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n}, t={t}, k={k}, d={d} (expected: {'YES' if expected else 'NO'})")
        
        try:
            # Set inputs
            if has_signal(dut, 'n'):
                dut.n.value = n
            else:
                raise TestFailure("Signal 'n' not found")
            
            if has_signal(dut, 't'):
                dut.t.value = t
            else:
                raise TestFailure("Signal 't' not found")
            
            if has_signal(dut, 'k'):
                dut.k.value = k
            else:
                raise TestFailure("Signal 'k' not found")
            
            if has_signal(dut, 'd'):
                dut.d.value = d
            else:
                raise TestFailure("Signal 'd' not found")
            
            # Wait for combinational logic to settle
            await Timer(100, units='ns')
            
            # Check output
            if not has_signal(dut, 'reason'):
                raise TestFailure("Signal 'reason' not found")
            
            if not is_value_defined(dut.reason.value):
                raise TestFailure("Output is undefined (X/Z)")
            
            result = int(dut.reason.value)
            
            if result != expected:
                raise TestFailure(f"Expected {'YES' if expected else 'NO'}, got {'YES' if result else 'NO'}")
            
            cocotb.log.info(f"  PASS: result = {'YES' if result else 'NO'}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")