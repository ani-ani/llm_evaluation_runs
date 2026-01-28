import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
MAX_N = 8
DATA_WIDTH = 16
INDEX_WIDTH = 3

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

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_tree_control(dut):
    """Test the tree_control module with scaled-down test cases."""
    
    # Test cases: (n, a_list, parent_list, weight_list, expected_ans)
    test_cases = [
        # Original test case 1 (scaled down)
        (
            5,
            [2, 5, 1, 4, 6],
            [0, 0, 2, 2],  # 0-indexed parents for vertices 1-4
            [7, 1, 5, 6],
            [1, 0, 1, 0, 0]
        ),
        # Original test case 2 (scaled down)
        (
            5,
            [9, 7, 8, 6, 5],
            [0, 1, 2, 3],  # 0-indexed parents
            [1, 1, 1, 1],
            [4, 3, 2, 1, 0]
        ),
        # Small test case: n=1
        (
            1,
            [1],
            [],  # No parents for n=1
            [],
            [0]
        ),
        # Small test case: n=2
        (
            2,
            [1, 1],
            [0],  # Vertex 1's parent is vertex 0
            [1],
            [1, 0]
        ),
        # Additional small test case
        (
            3,
            [5, 3, 10],
            [0, 0],  # Vertex 1 and 2 both have parent 0
            [2, 3],
            [1, 0, 0]
        ),
    ]
    
    total_passed = 0
    total_failed = 0
    
    for test_idx, (n, a_list, parent_list, weight_list, expected_ans) in enumerate(test_cases):
        dut._log.info(f"\nRunning Test Case {test_idx + 1}: n={n}")
        
        # Set n
        dut.n.value = n
        
        # Set a array
        for i in range(n):
            dut.a[i].value = a_list[i]
        
        # Set parent and weight arrays (only for n-1 elements)
        for i in range(n - 1):
            dut.parent[i].value = parent_list[i]
            dut.weight[i].value = weight_list[i]
        
        # Wait for combinational logic to settle
        await Timer(100, units='ns')
        
        # Check results
        test_passed = True
        for i in range(n):
            if not is_value_defined(dut.ans[i].value):
                dut._log.error(f"Test {test_idx + 1}: Output ans[{i}] is undefined (X/Z)")
                test_passed = False
                continue
            
            actual = int(dut.ans[i].value)
            expected = expected_ans[i]
            
            if actual != expected:
                dut._log.error(f"Test {test_idx + 1}: Vertex {i}: expected {expected}, got {actual}")
                test_passed = False
            else:
                dut._log.info(f"Test {test_idx + 1}: Vertex {i}: {actual} [PASS]")
        
        if test_passed:
            total_passed += 1
            dut._log.info(f"Test {test_idx + 1}: PASSED")
        else:
            total_failed += 1
            dut._log.error(f"Test {test_idx + 1}: FAILED")
    
    # Summary
    dut._log.info(f"\n{'='*60}")
    dut._log.info(f"SUMMARY: {total_passed}/{total_passed + total_failed} test cases passed")
    
    if total_failed > 0:
        raise TestFailure(f"{total_failed} test cases failed")