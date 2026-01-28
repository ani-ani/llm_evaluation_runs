import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Include mandatory helpers
def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_badge_decks(dut):
    """Test the badge decks calculation logic."""
    
    # Helper to drive inputs and check output
    async def check(b, g, n, expected):
        dut.b.value = clamp_to_width(b, 16)
        dut.g.value = clamp_to_width(g, 16)
        dut.n.value = clamp_to_width(n, 16)
        
        # Combinational, give time for propagation
        await Timer(10, units='ns')
        
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result undefined for b={b}, g={g}, n={n}")
            
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Input b={b}, g={g}, n={n}: Expected {expected}, got {result}")

    # Test cases from the problem statement and edge cases
    test_cases = [
        # (b, g, n, expected_output)
        (5, 6, 3, 4),      # Example 1
        (5, 3, 5, 4),      # Example 2
        (1, 200, 33, 2),   # n > b, g >= n
        (100, 200, 150, 101), # n > b, n > g (partial overlap)
        (123, 55, 100, 56),   # n > g, b >= n
        (300, 300, 600, 1),   # n > b, n > g, minimal overlap
        (1, 1, 1, 2),      # Edge: small numbers
        (100, 200, 250, 51),  # n > b, g > n
        (100, 200, 300, 1),   # n > b, n > g
        (123, 222, 250, 96),  # n > b, n > g
        (300, 300, 1, 2),     # n small, b/g large
        (300, 299, 300, 300), # n large, b >= n, g close to n
        (1, 1, 2, 1),      # n > b, n > g, exact fit
        (300, 1, 45, 2),   # n < b, n > g
        (199, 199, 199, 200), # n == b == g
        (297, 297, 298, 297), # n slightly > b/g
        (299, 259, 300, 259), # n > b, n > g
        (288, 188, 300, 177), # n > b, n > g
        (5, 299, 4, 5),    # n < b, n < g
        (199, 131, 45, 46), # n < b, n < g
        (50, 100, 120, 31),  # n > b, n > g
        (3, 3, 4, 3),      # n > b, n > g
        (4, 4, 5, 4),      # n > b, n > g
        (4, 4, 7, 2),      # n > b, n > g, limited by sum
        (3, 3, 5, 2),      # n > b, n > g, limited by sum
        (10, 10, 12, 9),   # n > b, n > g
        (5, 5, 9, 2),      # n > b, n > g
        (2, 2, 3, 2),      # n > b, n > g
        (5, 6, 10, 2),     # n > b, n > g
        (2, 56, 57, 2),    # n > b, n > g
        (4, 7, 10, 2),     # n > b, n > g
        (4, 3, 5, 3),      # n > b, n > g
        (7, 8, 10, 6),     # n > b, n > g
        (4, 2, 5, 2),      # n > b, n > g
        (3, 4, 5, 3)       # n > b, n > g
    ]
    
    passed = 0
    failed = 0
    
    for b, g, n, expected in test_cases:
        try:
            await check(b, g, n, expected)
            cocotb.log.info(f"PASS: b={b}, g={g}, n={n} -> {expected}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed.")
    else:
        cocotb.log.info(f"All {passed} tests passed!")
