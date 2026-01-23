import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_count_m(dut):
    """Test the count_m module."""
    
    # Wait for initial block to complete
    await Timer(100, units='ns')
    
    # Define test cases: (n, t, expected)
    test_cases = [
        (1, 1, 1),
        (3, 2, 1),
        (3, 3, 0),
        (1000000000000, 1048576, 118606527258),
        (35, 4, 11),
        (70, 32, 1),
        (79, 32, 1),
        (63, 16, 6),
        (6, 4, 1),
        (82, 16, 7),
        (4890852, 16, 31009),
        (473038165, 2, 406),
        (326051437, 4, 3601),
        (170427799, 16, 94897),
        (168544291, 8, 20039),
        (82426873, 1, 26),
        (175456797, 16384, 22858807),
        (257655784, 16384, 35969589),
        (9581849, 1024, 1563491),
        (8670529, 16384, 493388),
        (621597009, 268435456, 1),
        (163985731, 33554432, 27),
        (758646694, 67108864, 460),
        (304012333, 67108864, 28),
        (58797441, 33554432, 0),
        (445762753, 268435456, 0),
        (62695452, 33554432, 0),
        (47738179, 16777216, 1),
        (144342486, 67108864, 1),
        (138791611, 67108864, 1),
        (112400107, 67108864, 0),
        (119581441, 33554432, 3),
        (79375582, 67108864, 0),
        (121749691, 33554432, 3),
        (585863386, 33554432, 3655),
        (329622201, 19482151, 0),
        (303397385, 106697011, 0),
        (543649338, 175236010, 0),
        (341001112, 155173936, 0),
        (1000000000, 1000000001, 0),
        (1000000000000, 16, 657969),
        (1000000000000, 549755813888, 0),
        (1000000000000, 1048576, 118606527258),
        (987654321987, 1048576, 116961880791),
        (1000000000000, 1000000000000, 0),
    ]
    
    passed = 0
    failed = 0
    
    for n_val, t_val, expected in test_cases:
        dut.n.value = n_val
        dut.t.value = t_val
        
        # Wait for combinational logic to settle
        await Timer(100, units='ns')
        
        # Read result
        if not is_value_defined(dut.answer.value):
            dut._log.error(f"Test failed for n={n_val}, t={t_val}: answer is undefined (X/Z)")
            failed += 1
            continue
            
        result = int(dut.answer.value)
        
        if result == expected:
            dut._log.info(f"Test passed for n={n_val}, t={t_val}: {result}")
            passed += 1
        else:
            dut._log.error(f"Test failed for n={n_val}, t={t_val}: expected {expected}, got {result}")
            failed += 1
    
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")