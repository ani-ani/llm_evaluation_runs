import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout waiting for done after {max_cycles} cycles")

async def write_array(dut, vals):
    """Write values to arr_in array"""
    for i, v in enumerate(vals):
        if i < 8:  # Maximum 8 elements
            dut.arr_in[i].value = clamp_to_width(v, 8)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_remove_odd(dut):
    # Check if it's sequential (has clk)
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        # Setup clock
        clock = Clock(dut.clk, 10, units='ns')
        cocotb.start_soon(clock.start())
        await reset_dut(dut)
    else:
        # Combinational - set defaults
        if has_signal(dut, 'rst_n'):
            dut.rst_n.value = 1
    
    # Test cases
    test_cases = [
        ([1, 2, 3, 4, 5, 6, 7, 8], [2, 4, 6, 8, 0, 0, 0, 0], 4, "Basic filtering"),
        ([2, 4, 6, 8, 0, 0, 0, 0], [2, 4, 6, 8, 0, 0, 0, 0], 4, "All even"),
        ([1, 3, 5, 7, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0], 0, "All odd"),
        ([10, 20, 3, 0, 0, 0, 0, 0], [10, 20, 0, 0, 0, 0, 0, 0], 2, "Partial array"),
        ([0, 1, 2, 3, 4, 5, 6, 7], [0, 2, 4, 6, 0, 0, 0, 0], 4, "Includes zero"),
        ([255, 254, 1, 0, 0, 0, 0, 0], [254, 0, 0, 0, 0, 0, 0, 0], 1, "Max value test")
    ]
    
    passed = failed = 0
    
    for i, (input_arr, expected_arr, expected_count, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write input array
            await write_array(dut, input_arr)
            
            if is_seq:
                # Sequential: trigger start
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for completion
                await wait_for_done(dut, max_cycles=20)
                
                # Give one cycle for output to be stable
                await RisingEdge(dut.clk)
            else:
                # Combinational: wait for propagation
                await Timer(100, units='ns')
            
            # Read output array
            output_arr = []
            for j in range(8):
                if has_signal(dut, f'arr_out[{j}]') or has_signal(dut, f'arr_out'):
                    try:
                        val = int(dut.arr_out[j].value)
                        output_arr.append(val)
                    except:
                        # Try packed representation
                        val = int(dut.arr_out.value) >> (j * 8) & 0xFF
                        output_arr.append(val)
            
            # Read valid_count if available
            valid_count = 0
            if has_signal(dut, 'valid_count'):
                valid_count = int(dut.valid_count.value)
            
            # Verify results
            if len(output_arr) != 8:
                raise TestFailure(f"Expected 8 output elements, got {len(output_arr)}")
            
            if output_arr != expected_arr:
                raise TestFailure(f"Expected {expected_arr}, got {output_arr}")
            
            if has_signal(dut, 'valid_count') and valid_count != expected_count:
                raise TestFailure(f"Expected valid_count={expected_count}, got {valid_count}")
            
            # Log result
            cocotb.log.info(f"  Input:  {input_arr}")
            cocotb.log.info(f"  Output: {output_arr}")
            if has_signal(dut, 'valid_count'):
                cocotb.log.info(f"  Valid count: {valid_count}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            
        # Reset for next test
        if is_seq:
            await reset_dut(dut)
            await Timer(100, units='ns')
        else:
            if has_signal(dut, 'rst_n'):
                dut.rst_n.value = 0
                await Timer(50, units='ns')
                dut.rst_n.value = 1
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed, {passed} passed")
    else:
        cocotb.log.info(f"All {passed} tests passed!")