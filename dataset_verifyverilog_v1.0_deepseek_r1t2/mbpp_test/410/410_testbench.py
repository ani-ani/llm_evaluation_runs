import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 8
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

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def write_heterogeneous_list(dut, elements):
    """
    Write heterogeneous list to DUT.
    elements: list of tuples (type, value)
    type: 'str' or 'int'
    value: for 'int' it's the number, for 'str' it's the first char (simplified)
    """
    # Clear all first
    for i in range(ARRAY_SIZE):
        if has_signal(dut, f'valid_{i}'):
            getattr(dut, f'valid_{i}').value = 0
        elif has_signal(dut, 'valid'):
            dut.valid[i].value = 0
    
    # Write elements
    for i, (elem_type, elem_value) in enumerate(elements):
        if i >= ARRAY_SIZE:
            break
            
        # Set valid
        if has_signal(dut, f'valid_{i}'):
            getattr(dut, f'valid_{i}').value = 1
        elif has_signal(dut, 'valid'):
            dut.valid[i].value = 1
        
        # Set type code
        type_code = 1 if elem_type == 'str' else 0
        if has_signal(dut, f'type_code_{i}'):
            getattr(dut, f'type_code_{i}').value = type_code
        elif has_signal(dut, 'type_code'):
            dut.type_code[i].value = type_code
        
        # Set value
        # For strings, we'll use the ASCII value of first char (simplified)
        if elem_type == 'str':
            val = ord(elem_value[0]) if elem_value else 0
        else:
            val = elem_value
        
        if has_signal(dut, f'value_{i}'):
            getattr(dut, f'value_{i}').value = clamp_to_width(val, DATA_WIDTH)
        elif has_signal(dut, 'value'):
            dut.value[i].value = clamp_to_width(val, DATA_WIDTH)
    
    # Set num_elements
    num = min(len(elements), ARRAY_SIZE)
    if has_signal(dut, 'num_elements'):
        dut.num_elements.value = num

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(2):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut):
    """Wait for done signal with timeout."""
    for cycle in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {MAX_CYCLES} cycles")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_min_val_heterogeneous(dut):
    """Test minimum value finder in heterogeneous list."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases
    # Format: (elements_list, expected_min, description)
    # Elements: list of tuples (type, value) where type is 'int' or 'str'
    test_cases = [
        # Test 1: ['Python', 3, 2, 4, 5, 'version'] -> 2
        ([('str', 'Python'), ('int', 3), ('int', 2), ('int', 4), ('int', 5), ('str', 'version')], 
         2, "Test 1: Mixed with min=2"),
        
        # Test 2: ['Python', 15, 20, 25] -> 15
        ([('str', 'Python'), ('int', 15), ('int', 20), ('int', 25)], 
         15, "Test 2: Mixed with min=15"),
        
        # Test 3: ['Python', 30, 20, 40, 50, 'version'] -> 20
        ([('str', 'Python'), ('int', 30), ('int', 20), ('int', 40), ('int', 50), ('str', 'version')], 
         20, "Test 3: Mixed with min=20"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (elements, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\n{description}")
        
        try:
            # Write heterogeneous list to DUT
            await write_heterogeneous_list(dut, elements)
            
            # Set num_elements
            dut.num_elements.value = len(elements)
            
            # Pulse start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.min_value.value):
                raise TestFailure("min_value is undefined (X/Z)")
            
            if not is_value_defined(dut.error.value):
                raise TestFailure("error signal is undefined")
            
            result = int(dut.min_value.value)
            error = int(dut.error.value)
            
            # Check error flag first
            if error == 1:
                raise TestFailure(f"error flag set (no valid integers found)")
            
            # Verify result
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: min_value = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")