import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_SUBLISTS = 4
ELEMENTS_PER_SUBLIST = 3
RESULT_WIDTH = 3

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

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        # For signed, but we're using unsigned here
        return min(max_val, max(0, value))
    return min(max_val, max(0, value))

def pack_sublist(elements):
    """Pack a sublist into individual port values."""
    # Ensure exactly 3 elements, pad with 0 if needed
    padded = elements[:ELEMENTS_PER_SUBLIST]
    while len(padded) < ELEMENTS_PER_SUBLIST:
        padded.append(0)
    return padded

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_count_element(dut):
    """Test counting element occurrences in sublists."""
    
    # Test cases: (sublists, search_element, expected_count, description)
    # Sublists are lists of lists, each inner list has 3 elements (padded)
    test_cases = [
        (
            [[1, 3, 0], [5, 7, 0], [1, 11, 0], [1, 15, 7]],
            1,
            3,
            "Test 1: Three sublists contain 1"
        ),
        (
            [[ord('A'), ord('B'), 0], [ord('A'), ord('C'), 0], [ord('A'), ord('D'), ord('E')], [ord('B'), ord('C'), ord('D')]],
            ord('A'),
            3,
            "Test 2: Three sublists contain 'A'"
        ),
        (
            [[ord('A'), ord('B'), 0], [ord('A'), ord('C'), 0], [ord('A'), ord('D'), ord('E')], [ord('B'), ord('C'), ord('D')]],
            ord('E'),
            1,
            "Test 3: One sublist contains 'E'"
        ),
        (
            [[1, 2, 3], [4, 5, 6], [7, 8, 9], [10, 11, 12]],
            99,
            0,
            "Test 4: No sublists contain the element"
        ),
        (
            [[1, 1, 1], [1, 1, 1], [1, 1, 1], [1, 1, 1]],
            1,
            4,
            "Test 5: All four sublists contain the element"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (sublists, search_elem, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {test_idx + 1}: {description}")
        
        try:
            # Set all sublist element inputs
            for sublist_idx, sublist in enumerate(sublists):
                packed = pack_sublist(sublist)
                
                # Access each element individually
                for elem_idx, value in enumerate(packed):
                    port_name = f"s{sublist_idx}_{elem_idx}"
                    if hasattr(dut, port_name):
                        port = getattr(dut, port_name)
                        port.value = clamp_to_width(value, DATA_WIDTH)
                    else:
                        raise TestFailure(f"Port {port_name} not found in DUT")
            
            # Set search element
            dut.search_element.value = clamp_to_width(search_elem, DATA_WIDTH)
            
            # Wait for combinational logic to settle
            await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.count.value):
                raise TestFailure(f"Count output is undefined (X/Z)")
            
            result = int(dut.count.value)
            
            # Verify result
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: count = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Small delay between tests
        await Timer(10, units='ns')
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Test Results: {passed}/{passed+failed} passed")
    cocotb.log.info(f"{'='*60}")
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")