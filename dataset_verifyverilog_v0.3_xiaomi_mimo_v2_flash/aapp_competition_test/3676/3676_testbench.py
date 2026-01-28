import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 2
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================
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

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_polygon_count(dut):
    """Test all (R,C) pairs from 1 to 4."""
    
    # Expected values for (R,C): index = ((R-1)*4 + (C-1))
    expected = [
        1,   3,   6,   10,
        3,   13,  41,  108,
        6,   41,  128, 355,
        10,  108, 355, 1190
    ]
    
    # Iterate over all R,C from 1 to 4
    for r in range(1,5):
        for c in range(1,5):
            # Encode R and C as 2-bit values: 0->0, 1->1, 2->2, 3->3
            dut.R.value = r - 1
            dut.C.value = c - 1
            
            # Wait for combinational logic to settle
            await Timer(100, units='ns')
            
            # Read output
            if not is_value_defined(dut.count.value):
                raise TestFailure(f"Output count is undefined for R={r}, C={c}")
            
            actual = int(dut.count.value)
            exp = expected[(r-1)*4 + (c-1)]
            
            if actual != exp:
                raise TestFailure(f"R={r}, C={c}: expected {exp}, got {actual}")
            
            dut._log.info(f"R={r}, C={c} -> count={actual} [PASS]")
    
    dut._log.info("All tests passed!")
