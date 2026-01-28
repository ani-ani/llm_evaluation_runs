import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def to_fixed_point(value):
    """Convert float to Q16.16 fixed-point integer."""
    return int(value * 65536)

def from_fixed_point(value):
    """Convert Q16.16 fixed-point integer to float."""
    return value / 65536.0

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_find_closest_elements(dut):
    """Test find_closest_elements module"""
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.arr_0.value = 0
    dut.arr_1.value = 0
    dut.arr_2.value = 0
    dut.arr_3.value = 0
    dut.arr_4.value = 0
    dut.arr_5.value = 0
    
    await RisingEdge(dut.clk)
    await Timer(1, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (input_list, expected_min, expected_max)
    # Inputs are floats, we convert to fixed point
    test_cases = [
        ([1.0, 2.0, 3.9, 4.0, 5.0, 2.2], 3.9, 4.0),
        ([1.0, 2.0, 5.9, 4.0, 5.0], 5.0, 5.9),
        ([1.0, 2.0, 3.0, 4.0, 5.0, 2.2], 2.0, 2.2),
        ([1.0, 2.0, 3.0, 4.0, 5.0, 2.0], 2.0, 2.0),
        ([1.1, 2.2, 3.1, 4.1, 5.1], 2.2, 3.1),
    ]
    
    dut._log.info(f"Running {len(test_cases)} test cases...")
    passed = 0
    total = len(test_cases)
    
    for i, (input_list, expected_min, expected_max) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: Input {input_list}")
        
        # Pad input list to 6 elements if necessary (design expects 6 inputs)
        # The problem says "length at least two" but our design handles 6 fixed slots.
        # We will assume the input list maps to the first N slots and rest are 0 or ignored?
        # Wait, the design needs exactly 6 inputs based on the prompt.
        # However, the test case [1.0, 2.0, 5.9, 4.0, 5.0] has 5 elements.
        # Let's assume 0-padding for missing elements, BUT 0 is a valid number.
        # If we pad with 0, it might become the closest.
        # BETTER: The design should handle valid inputs. Since the prompt says 6 inputs, 
        # we need to provide 6 inputs. 
        # Let's repeat the last element or pad with a very large value so it's never closest?
        # Actually, let's just follow the prompt: design takes 6 inputs.
        # For the 5-element test case, we can set the 6th input to a large value (e.g., 100.0) 
        # so it doesn't interfere with the closest pair of the 5.
        
        padded_input = list(input_list)
        while len(padded_input) < 6:
            padded_input.append(100.0)  # Pad with large value
            
        # Assign to DUT
        dut.arr_0.value = to_fixed_point(padded_input[0])
        dut.arr_1.value = to_fixed_point(padded_input[1])
        dut.arr_2.value = to_fixed_point(padded_input[2])
        dut.arr_3.value = to_fixed_point(padded_input[3])
        dut.arr_4.value = to_fixed_point(padded_input[4])
        dut.arr_5.value = to_fixed_point(padded_input[5])
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (max 10 cycles to be safe)
        done_seen = False
        for _ in range(10):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                done_seen = True
                break
        
        if not done_seen:
            raise TestFailure(f"Test {i+1}: Done signal not asserted within 10 cycles")
            
        # Read outputs
        if not is_value_defined(dut.min_val.value) or not is_value_defined(dut.max_val.value):
            raise TestFailure(f"Test {i+1}: Output values undefined")
            
        result_min = from_fixed_point(int(dut.min_val.value))
        result_max = from_fixed_point(int(dut.max_val.value))
        
        # Compare
        # Use small tolerance for floating point comparison
        if abs(result_min - expected_min) > 0.001 or abs(result_max - expected_max) > 0.001:
            raise TestFailure(f"Test {i+1}: Expected ({expected_min}, {expected_max}), got ({result_min}, {result_max})")
        
        dut._log.info(f"Test {i+1} Passed: ({result_min}, {result_max})")
        passed += 1
        
        # Wait for next test (ensure done goes low)
        await RisingEdge(dut.clk)
    
    dut._log.info(f"Summary: {passed}/{total} tests passed")
