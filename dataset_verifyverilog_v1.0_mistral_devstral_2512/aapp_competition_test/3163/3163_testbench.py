import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
N = 3
M = 4
DATA_WIDTH = 8

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

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_config(dut, config, prefix):
    """Write configuration to individual ports."""
    for i in range(N):
        for j in range(M):
            port_name = f"{prefix}_{i}_{j}"
            if has_signal(dut, port_name):
                getattr(dut, port_name).value = clamp_to_width(config[i][j], DATA_WIDTH)
            else:
                raise TestFailure(f"Signal {port_name} not found")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_book_rearrangement(dut):
    """Test the book rearrangement module."""
    
    # Define test cases
    test_cases = [
        (
            [
                [1, 0, 2, 0],
                [3, 5, 4, 0],
                [0, 0, 0, 0]
            ],
            [
                [2, 1, 0, 0],
                [3, 0, 4, 5],
                [0, 0, 0, 0]
            ],
            2,
            "Example 1"
        ),
        (
            [
                [1, 2, 3, 0],
                [4, 5, 6, 0],
                [7, 8, 0, 0]
            ],
            [
                [4, 2, 3, 0],
                [6, 5, 1, 0],
                [0, 7, 8, 0]
            ],
            4,
            "Example 2"
        ),
        (
            [
                [1, 2, 0, 0],
                [3, 4, 0, 0],
                [0, 0, 0, 0]
            ],
            [
                [2, 3, 0, 0],
                [4, 1, 0, 0],
                [0, 0, 0, 0]
            ],
            -1,
            "Example 3"
        )
    ]
    
    passed = 0
    failed = 0
    
    for initial, target, expected, description in test_cases:
        cocotb.log.info(f"Testing {description}")
        
        # Write initial configuration
        await write_config(dut, initial, "initial_config")
        
        # Write target configuration
        await write_config(dut, target, "target_config")
        
        # Wait for combinatorial logic to settle
        await Timer(10, units='ns')
        
        # Read result
        if not is_value_defined(dut.liftings.value):
            cocotb.log.error(f"  FAIL: Output is undefined")
            failed += 1
            continue
        
        result = to_signed(int(dut.liftings.value), 8)
        
        if result == expected:
            cocotb.log.info(f"  PASS: liftings = {result}")
            passed += 1
        else:
            cocotb.log.error(f"  FAIL: Expected {expected}, got {result}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")