import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def float_to_q16_16(f):
    """Convert float to Q16.16 integer representation."""
    return int(f * 65536)

def q16_16_to_float(q):
    """Convert Q16.16 integer to float."""
    return q / 65536.0

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

async def wait_for_done(dut, max_cycles=100):
    """Wait for done signal to go high."""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            return
    raise TestFailure(f"Done signal did not go high after {max_cycles} cycles")

async def collect_output(dut, length):
    """Collect rescaled values from the module."""
    results = []
    for i in range(length):
        # Wait for out_valid
        for _ in range(20):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.out_valid.value) and dut.out_valid.value == 1:
                break
        else:
            raise TestFailure(f"out_valid did not go high for element {i}")
        
        if not is_value_defined(dut.data_out.value):
            raise TestFailure(f"data_out is undefined for element {i}")
        
        val = int(dut.data_out.value)
        results.append(q16_16_to_float(val))
    return results

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_rescale_unit(dut):
    """Test the rescale_unit module with various test cases."""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in.value = 0
    dut.len.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        ([2.0, 49.9], [0.0, 1.0]),
        ([100.0, 49.9], [1.0, 0.0]),
        ([1.0, 2.0, 3.0, 4.0, 5.0], [0.0, 0.25, 0.5, 0.75, 1.0]),
        ([2.0, 1.0, 5.0, 3.0, 4.0], [0.25, 0.0, 1.0, 0.5, 0.75]),
        ([12.0, 11.0, 15.0, 13.0, 14.0], [0.25, 0.0, 1.0, 0.5, 0.75]),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (input_vals, expected_vals) in enumerate(test_cases):
        dut._log.info(f"Running Test Case {i+1}: {input_vals}")
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Set length
        dut.len.value = len(input_vals)
        
        # Feed inputs sequentially
        for val in input_vals:
            dut.data_in.value = float_to_q16_16(val)
            await RisingEdge(dut.clk)
        
        # Wait for done
        await wait_for_done(dut, max_cycles=50)
        
        # Collect outputs
        try:
            results = collect_output(dut, len(input_vals))
            
            # Compare with expected (tolerance for fixed-point error)
            tolerance = 0.001
            match = True
            for r, e in zip(results, expected_vals):
                if abs(r - e) > tolerance:
                    match = False
                    dut._log.error(f"Mismatch: got {r:.6f}, expected {e:.6f}")
            
            if match:
                passed += 1
                dut._log.info(f"Test Case {i+1} passed [OK]")
            else:
                raise TestFailure(f"Test Case {i+1} failed")
                
        except TestFailure as tf:
            dut._log.error(str(tf))
            raise
    
    dut._log.info(f"Summary: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
