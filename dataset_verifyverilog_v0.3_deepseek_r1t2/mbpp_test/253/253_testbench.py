import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_count_integer(dut):
    """Test count_integer module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases mapping
    # Python types need to be mapped to byte representations:
    # - int: Use raw value if < 256, else use high bytes (treated as integer)
    # - str: Use ASCII values, but strings have values >= 32
    # - float: Use a marker value (e.g., 1.2 becomes 12 with special handling)
    # 
    # Simplified approach for hardware:
    # Values 0-31 or > 126: Integer (counted)
    # Values 32-126: String/Character (not counted)
    # We'll map Python test cases to this scheme
    
    # Test 1: [1, 2, 'abc', 1.2] -> expect 2 integers
    # Mapping: 1->1, 2->2, 'abc'->97, 98, 99 (but we only use 4 elements)
    #          1.2->12
    # Actual test: We need to encode types as byte values
    # Let's use: integers are values < 32, others >= 32
    # 1 -> 1, 2 -> 2, 'a' -> 97, 1.2 -> 12 (but 12 < 32, would count as int)
    # Need different encoding: We'll use 0-9 for ints, 32+ for others
    
    # Revised test case 1: [1, 2, 'abc', 1.2] -> 2 integers
    # Encode: 1->1, 2->2, 'a'->97, 1.2->12
    # But 12 < 32, would count. Let's use 250+ for floats, 32-126 for strings
    # Actually, simpler: We'll test [1, 2, 3, 4] = 4, [0,0,0,0] = 0, [5, 'a', 'b', 6] = 2
    
    test_cases = [
        # (arr_0, arr_1, arr_2, arr_3, expected_count, description)
        (1, 2, 3, 4, 4, "All integers [1,2,3,4]"),
        (0, 0, 0, 0, 4, "All zeros [0,0,0,0]"),
        (1, 97, 98, 2, 2, "Mixed [1,'a','b',2] -> 2 integers"),
        (97, 98, 99, 100, 0, "All strings [a,b,c,d] -> 0 integers"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (val0, val1, val2, val3, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Write inputs - handle potential index issues
            if has_signal(dut, 'arr_0'):
                dut.arr_0.value = val0
                dut.arr_1.value = val1
                dut.arr_2.value = val2
                dut.arr_3.value = val3
            elif has_signal(dut, 'arr'):
                dut.arr[0].value = val0
                dut.arr[1].value = val1
                dut.arr[2].value = val2
                dut.arr[3].value = val3
            else:
                raise TestFailure("Cannot find array signals")
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")