import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_warlords_add_lines(dut):
    """Test the warlords_add_lines module."""
    
    # Detect if sequential or combinational
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock if sequential
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        # Reset (active-low)
        if has_signal(dut, 'rst_n'):
            dut.rst_n.value = 0
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            dut.rst_n.value = 1
            await RisingEdge(dut.clk)
    
    # Define test cases: (W, lines, expected_result)
    # lines: list of tuples (type, coord) where type is 'H' or 'V'
    test_cases = [
        # Case 1: 2 warlords, 1 horizontal line -> I=2, answer 0
        (2, [('H', 5)], 0),
        # Case 2: 5 warlords, 1 horizontal, 1 vertical -> I=4, answer 1
        (5, [('H', 5), ('V', 0)], 1),
        # Case 3: 3 warlords, 2 horizontal lines (distinct) -> I=3, answer 0
        (3, [('H', 5), ('H', 6)], 0),
        # Case 4: 4 warlords, 3 horizontal lines -> I=4, answer 0
        (4, [('H', 1), ('H', 2), ('H', 3)], 0),
        # Case 5: 4 warlords, 2 horizontal, 1 vertical -> I=6, answer 0
        (4, [('H', 1), ('H', 2), ('V', 0)], 0),
        # Case 6: 1 warlord, no lines -> I=1, answer 0
        (1, [], 0),
        # Case 7: 2 warlords, no lines -> I=1, answer 1
        (2, [], 1),
        # Case 8: 3 warlords, no lines -> I=1, answer 2
        (3, [], 2),
        # Case 9: 4 warlords, no lines -> I=1, answer 2
        (4, [], 2),
        # Case 10: 5 warlords, no lines -> I=1, answer 3
        (5, [], 3),
        # Case 11: 3 warlords, 1 vertical line -> I=2, answer 1
        (3, [('V', 0)], 1),
        # Case 12: 6 warlords, 2 horizontal, 2 vertical (all distinct) -> I=8, answer 0
        (6, [('H', 1), ('H', 2), ('V', 3), ('V', 4)], 0),
        # Case 13: 7 warlords, 2 horizontal, 2 vertical -> I=8, answer 0
        (7, [('H', 1), ('H', 2), ('V', 3), ('V', 4)], 0),
        # Case 14: 8 warlords, 2 horizontal, 2 vertical -> I=8, answer 0
        (8, [('H', 1), ('H', 2), ('V', 3), ('V', 4)], 0),
        # Case 15: 9 warlords, 2 horizontal, 2 vertical -> I=8, deficit=1, answer 1
        (9, [('H', 1), ('H', 2), ('V', 3), ('V', 4)], 1),
    ]
    
    passed = 0
    failed = 0
    
    for i, (W, lines, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: W={W}, lines={lines}")
        
        # Prepare inputs
        num_lines = len(lines)
        type_mask = 0
        valid_mask = 0
        coords = [0]*8
        
        for idx, (typ, coord) in enumerate(lines):
            if typ == 'H':
                type_mask |= (0 << idx)
            else:  # 'V'
                type_mask |= (1 << idx)
            valid_mask |= (1 << idx)
            coords[idx] = coord
        
        # Assign to DUT
        if has_signal(dut, 'type_in'):
            dut.type_in.value = type_mask
        
        # coord_in is an array of 8 signals
        for idx in range(8):
            if hasattr(dut, 'coord_in'):
                # Direct array indexing
                dut.coord_in[idx].value = clamp_to_width(coords[idx], 8)
            else:
                # Fallback to individual ports (not expected)
                pass
        
        if has_signal(dut, 'valid_in'):
            dut.valid_in.value = valid_mask
        
        dut.warlords.value = W
        
        # For combinational, wait a bit for propagation
        if not is_sequential:
            await Timer(100, units='ns')
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined")
        
        result = int(dut.result.value)
        
        if result != expected:
            cocotb.log.error(f"  FAIL: expected {expected}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")