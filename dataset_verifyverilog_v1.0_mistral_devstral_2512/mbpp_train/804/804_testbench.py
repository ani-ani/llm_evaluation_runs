import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
ARRAY_SIZE = 8

# Helper functions
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

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def write_array(dut, values):
    """Write values to individual array ports."""
    # Pad values to ARRAY_SIZE with zeros
    padded_values = values + [0] * (ARRAY_SIZE - len(values))
    
    for i in range(min(len(values), ARRAY_SIZE)):
        port_name = f'arr_{i}'
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(values[i], DATA_WIDTH)
        else:
            raise TestFailure(f"Port {port_name} not found")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_is_product_even(dut):
    """Test the is_product_even module."""
    
    # Initialize all inputs
    for i in range(ARRAY_SIZE):
        port_name = f'arr_{i}'
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = 0
    
    if has_signal(dut, 'len'):
        dut.len.value = 0
    
    # Wait for initial propagation
    await Timer(10, units='ns')
    
    # Test cases
    test_cases = [
        ([1, 2, 3], 1, "Product of [1,2,3] is 6 (even)"),
        ([1, 2, 1, 4], 1, "Product of [1,2,1,4] is 8 (even)"),
        ([1, 1], 0, "Product of [1,1] is 1 (odd)"),
        ([3, 5, 7, 9], 0, "Product of [3,5,7,9] is 945 (odd)"),
        ([2], 1, "Single even number"),
        ([3], 0, "Single odd number"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_list, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Write inputs
            await write_array(dut, input_list)
            
            # Set length
            if has_signal(dut, 'len'):
                dut.len.value = len(input_list)
            
            # Wait for combinational logic
            await Timer(10, units='ns')
            
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