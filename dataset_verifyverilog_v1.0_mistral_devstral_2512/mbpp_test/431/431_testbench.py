import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

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
    return min(max_val, max(0, value))

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
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

async def write_list(dut, list_name, values, element_width):
    """Write values to array elements."""
    for i in range(ARRAY_SIZE):
        if i < len(values):
            val = clamp_to_width(values[i], element_width)
            dut._log.info(f"  Setting {list_name}[{i}] = 0x{val:02X}")
        else:
            val = 0
        
        # Try indexed array access
        try:
            getattr(dut, list_name)[i].value = val
            continue
        except (AttributeError, TypeError):
            pass
        
        # Try individual port access
        port_name = f"{list_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = val
        else:
            raise TestFailure(f"Cannot find array port: {list_name}[{i}] or {port_name}")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_common_element(dut):
    """Test common element detection."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases adapted for 8-element arrays, 8-bit values
    # Format: (list1, list2, expected_result, description)
    test_cases = [
        # Test 1: [1,2,3,4,5] vs [5,6,7,8,9] -> True (common element 5)
        (
            [0x01, 0x02, 0x03, 0x04, 0x05],
            [0x05, 0x06, 0x07, 0x08, 0x09],
            1,
            "Test 1: Common element 0x05"
        ),
        # Test 2: [1,2,3,4,5] vs [6,7,8,9] -> False
        (
            [0x01, 0x02, 0x03, 0x04, 0x05],
            [0x06, 0x07, 0x08, 0x09],
            0,
            "Test 2: No common elements"
        ),
        # Test 3: ['a','b','c'] vs ['d','b','e'] -> True (common element 'b')
        # 'a'=0x61, 'b'=0x62, 'c'=0x63, 'd'=0x64, 'e'=0x65
        (
            [0x61, 0x62, 0x63],
            [0x64, 0x62, 0x65],
            1,
            "Test 3: Common element 'b' (0x62)"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for i, (list1_vals, list2_vals, expected, description) in enumerate(test_cases):
        dut._log.info(f"\n{'='*60}")
        dut._log.info(f"Test {i+1}: {description}")
        dut._log.info(f"{'='*60}")
        
        try:
            # Write both lists
            dut._log.info(f"Writing list1 (len={len(list1_vals)}): {list1_vals}")
            await write_list(dut, 'list1', list1_vals, DATA_WIDTH)
            
            dut._log.info(f"Writing list2 (len={len(list2_vals)}): {list2_vals}")
            await write_list(dut, 'list2', list2_vals, DATA_WIDTH)
            
            # Set lengths (length-1 as per spec: 0=1 element, 7=8 elements)
            dut.len1.value = len(list1_vals) - 1
            dut.len2.value = len(list2_vals) - 1
            dut._log.info(f"Setting len1={len(list1_vals)-1}, len2={len(list2_vals)-1}")
            
            # Pulse start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.has_common.value):
                raise TestFailure("Result has_common is undefined (X/Z)")
            
            result = int(dut.has_common.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            dut._log.info(f"Result: {result} (PASS)")
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"FAILED: {e}")
            failed += 1
            
        # Wait one cycle before next test
        await RisingEdge(dut.clk)
    
    # Summary
    dut._log.info(f"\n{'='*60}")
    dut._log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    dut._log.info(f"{'='*60}")
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")