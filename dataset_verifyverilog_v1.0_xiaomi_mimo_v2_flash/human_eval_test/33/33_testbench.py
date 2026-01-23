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

def pack_array(values):
    """Pack 8 values into a single 64-bit integer for array assignment."""
    result = 0
    for i, val in enumerate(values):
        result |= (val & 0xFF) << (i * 8)
    return result

def unpack_array(packed_value):
    """Extract 8 bytes from a 64-bit integer."""
    return [(packed_value >> (i * 8)) & 0xFF for i in range(8)]

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_sort_third(dut):
    """Test sort_third module with various test cases."""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.arr.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases: (input_list, expected_list)
    test_cases = [
        ([1, 2, 3], [1, 2, 3]),
        ([5, 6, 3, 4, 8, 9, 2], [2, 6, 3, 4, 8, 9, 5]),
        ([5, 3, -5, 2, -3, 3, 9, 0, 123, 1, -10], [5, 3, -5, 2, -3, 3, 9, 0, 123, 1, -10]),
        ([5, 8, -12, 4, 23, 2, 3, 11, 12, -10], [5, 8, -12, 4, 23, 2, 3, 11, 12, -10]),
        ([5, 6, 3, 4, 8, 9, 2], [2, 6, 3, 4, 8, 9, 5]),
        ([5, 8, 3, 4, 6, 9, 2], [2, 8, 3, 4, 6, 9, 5]),
        ([5, 6, 9, 4, 8, 3, 2], [2, 6, 9, 4, 8, 3, 5]),
        ([5, 6, 3, 4, 8, 9, 2, 1], [2, 6, 3, 4, 8, 9, 5, 1]),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_list, expected_list) in enumerate(test_cases):
        dut._log.info(f"Test case {i+1}: Input={input_list}")
        
        # Extend or truncate input to 8 elements
        input_padded = input_list[:8] + [0] * (8 - len(input_list))
        
        # Convert negative values to unsigned 8-bit
        input_unsigned = []
        for val in input_padded:
            if val < 0:
                input_unsigned.append(val & 0xFF)
            else:
                input_unsigned.append(val)
        
        # Assign input array element by element
        for j in range(8):
            dut.arr[j].value = input_unsigned[j]
        
        # Pulse start
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done with timeout
        done_found = False
        for cycle in range(100):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                done_found = True
                break
        
        if not done_found:
            dut._log.error(f"Test {i+1}: Done signal not received within 100 cycles")
            failed += 1
            continue
        
        # Read output array
        output_unsigned = []
        all_defined = True
        for j in range(8):
            if not is_value_defined(dut.result[j].value):
                dut._log.error(f"Test {i+1}: Output at index {j} is undefined")
                all_defined = False
                break
            output_unsigned.append(int(dut.result[j].value))
        
        if not all_defined:
            failed += 1
            continue
        
        # Convert unsigned to signed for comparison
        output_signed = []
        for val in output_unsigned:
            if val > 127:
                output_signed.append(val - 256)
            else:
                output_signed.append(val)
        
        # Compare
        # Only check up to the length of the original input
        test_passed = True
        for j in range(len(input_list)):
            if output_signed[j] != expected_list[j]:
                dut._log.error(f"Test {i+1} FAILED at index {j}: expected {expected_list[j]}, got {output_signed[j]}")
                test_passed = False
                break
        
        if test_passed:
            dut._log.info(f"Test {i+1} PASSED")
            passed += 1
        else:
            failed += 1
        
        # Wait a few cycles before next test
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\n=== Summary: {passed}/{len(test_cases)} tests passed ===")
    
    if failed > 0:
        raise TestFailure(f"{failed} out of {len(test_cases)} tests failed")
