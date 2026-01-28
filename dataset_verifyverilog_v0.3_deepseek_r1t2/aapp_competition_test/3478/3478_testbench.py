import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
CLK_PERIOD_NS = 10

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

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_graph_partition_4(dut):
    """Test graph partition for n=4"""
    
    # Test cases: (adj13, adj14, adj23, adj24, adj34, expected_possible, expected_aryas, expected_sansas)
    test_cases = [
        # Test case 1: possible
        (1, 1, 1, 1, 1, 1, 0b1101, 0b0010),
        # Test case 2: impossible
        (1, 1, 1, 1, 0, 0, 0b0000, 0b0000),
    ]
    
    for i, (adj13, adj14, adj23, adj24, adj34, exp_possible, exp_aryas, exp_sansas) in enumerate(test_cases):
        cocotb.log.info(f"Test case {i+1}: adj13={adj13}, adj14={adj14}, adj23={adj23}, adj24={adj24}, adj34={adj34}")
        
        # Set inputs
        dut.adj13.value = adj13
        dut.adj14.value = adj14
        dut.adj23.value = adj23
        dut.adj24.value = adj24
        dut.adj34.value = adj34
        
        # Wait for combinational logic to settle
        await Timer(100, units='ns')
        
        # Read outputs
        if not is_value_defined(dut.possible.value):
            raise TestFailure(f"Test {i+1}: possible signal is undefined (X/Z)")
        
        actual_possible = int(dut.possible.value)
        actual_aryas = int(dut.aryas_set.value)
        actual_sansas = int(dut.sansas_set.value)
        
        # Verify possible
        if actual_possible != exp_possible:
            raise TestFailure(f"Test {i+1}: possible mismatch - expected {exp_possible}, got {actual_possible}")
        
        # If possible, verify sets
        if exp_possible == 1:
            if actual_aryas != exp_aryas:
                raise TestFailure(f"Test {i+1}: aryas_set mismatch - expected {exp_aryas:b}, got {actual_aryas:b}")
            if actual_sansas != exp_sansas:
                raise TestFailure(f"Test {i+1}: sansas_set mismatch - expected {exp_sansas:b}, got {actual_sansas:b}")
        
        cocotb.log.info(f"  PASS: possible={actual_possible}, aryas={actual_aryas:04b}, sansas={actual_sansas:04b}")
    
    cocotb.log.info("All tests passed!")
