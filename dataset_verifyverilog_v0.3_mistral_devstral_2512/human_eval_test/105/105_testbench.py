import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def ascii_to_packed(ascii_str):
    """Convert string like 'One' to 32-bit packed value."""
    if len(ascii_str) > 4:
        raise ValueError(f"String {ascii_str} too long for 32-bit packing")
    result = 0
    for i, char in enumerate(ascii_str):
        result |= ord(char) << ((3 - i) * 8)
    # Pad with nulls if less than 4 chars
    return result

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_by_length_processor(dut):
    """Test the by_length processor module."""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 1
    dut.start.value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        # (input_array, expected_output_list)
        ([2, 1, 1, 4, 5, 8, 2, 3], ["Eight", "Five", "Four", "Three", "Two", "Two", "One", "One"]),
        ([0, 0, 0, 0, 0, 0, 0, 0], []),
        ([1, 55, 255, 100, 1, 9, 9, 9], ["Nine", "Nine", "Nine", "One", "One"]),
        ([1, -1, 3, 2, 0, 0, 0, 0], ["Three", "Two", "One"]),
        ([9, 4, 8, 0, 0, 0, 0, 0], ["Nine", "Eight", "Four"]),
        ([2, 1, 1, 4, 5, 8, 2, 3], ["Eight", "Five", "Four", "Three", "Two", "Two", "One", "One"]),  # Duplicate test
        ([1, 1, 1, 1, 1, 1, 1, 1], ["One", "One", "One", "One", "One", "One", "One", "One"]),
        ([9, 8, 7, 6, 5, 4, 3, 2], ["Nine", "Eight", "Seven", "Six", "Five", "Four", "Three", "Two"]),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (input_arr, expected_output) in enumerate(test_cases):
        dut._log.info(f"Test case {i+1}: input={input_arr}, expected={expected_output}")
        
        # Check if done signal exists (sequential module)
        has_done = hasattr(dut, 'done')
        
        # Assign input array
        for j in range(8):
            dut.arr[j].value = input_arr[j]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion with timeout
        MAX_CYCLES = 150
        done_seen = False
        
        for cycle in range(MAX_CYCLES):
            await RisingEdge(dut.clk)
            
            if has_done:
                if is_value_defined(dut.done.value):
                    if dut.done.value == 1:
                        done_seen = True
                        break
            else:
                # Combinational - wait for propagation
                await Timer(50, units="ns")
                done_seen = True
                break
        
        if not done_seen and has_done:
            raise TestFailure(f"Test {i+1}: Timeout after {MAX_CYCLES} cycles")
        
        # Verify outputs are defined
        valid_count = int(dut.valid_count.value)
        
        # Check each output string
        actual_output = []
        for j in range(8):
            if j >= valid_count:
                break
            
            output_signal = getattr(dut, f'result_{j}')
            if not is_value_defined(output_signal.value):
                raise TestFailure(f"Test {i+1}: Output result_{j} is undefined")
            
            packed = int(output_signal.value)
            
            # Convert packed to string
            chars = []
            for pos in range(4):
                byte = (packed >> ((3 - pos) * 8)) & 0xFF
                if byte != 0:
                    chars.append(chr(byte))
            string_val = ''.join(chars)
            actual_output.append(string_val)
        
        # Verify
        if len(actual_output) != len(expected_output):
            raise TestFailure(f"Test {i+1}: Length mismatch. Expected {len(expected_output)}, got {len(actual_output)} (output: {actual_output})")
        
        for j in range(len(actual_output)):
            if actual_output[j] != expected_output[j]:
                raise TestFailure(f"Test {i+1}: Output {j} mismatch. Expected {expected_output[j]}, got {actual_output[j]}")
        
        dut._log.info(f"Test case {i+1} passed")
        passed += 1
        
        # Small delay between tests
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\nTest Summary: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
