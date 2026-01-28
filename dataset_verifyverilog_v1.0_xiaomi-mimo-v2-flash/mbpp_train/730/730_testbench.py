import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

DATA_WIDTH = 8
MAX_LEN = 16
CLK_NS = 10
MAX_CYCLES = 1000

async def write_input_array(dut, values):
    """Write values to input_data array elements individually"""
    for i in range(MAX_LEN):
        if i < len(values):
            dut.input_data[i].value = clamp_to_width(values[i], DATA_WIDTH)
        else:
            dut.input_data[i].value = 0

async def read_output_array(dut):
    """Read output_data array elements individually and return list"""
    result = []
    output_len = safe_int(dut.output_len.value)
    for i in range(output_len):
        val = safe_int(dut.output_data[i].value)
        result.append(val)
    return result

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_consecutive_duplicates(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (input_list, expected_output_list, description)
    test_cases = [
        ([0, 0, 1, 2, 3, 4, 4, 5, 6, 6, 6, 7, 8, 9, 4, 4], 
         [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 4], 
         "Basic consecutive duplicates with repeats"),
        ([10, 10, 15, 19, 18, 18, 17, 26, 26, 17, 18, 10], 
         [10, 15, 19, 18, 17, 26, 17, 18, 10], 
         "Mid-range values with consecutive duplicates"),
        ([97, 97, 98, 99, 100, 100], 
         [97, 98, 99, 100], 
         "ASCII values for 'a', 'b', 'c', 'd'"),
        ([97, 97, 98, 99, 100, 100, 97, 97], 
         [97, 98, 99, 100, 97], 
         "ASCII values with non-consecutive duplicates"),
        ([5, 5, 5, 5], 
         [5], 
         "All identical elements"),
        ([1, 2, 3, 4], 
         [1, 2, 3, 4], 
         "No duplicates at all"),
        ([1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8], 
         [1, 2, 3, 4, 5, 6, 7, 8], 
         "Perfect pairs for all 16 elements"),
        ([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 
         [0], 
         "All zeros"),
        ([255, 255, 254, 254], 
         [255, 254], 
         "Maximum and near-maximum values"),
        ([1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2], 
         [1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2], 
         "Alternating values (no consecutive duplicates)"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, expected_out, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        cocotb.log.info(f"  Input: {inp}")
        cocotb.log.info(f"  Expected: {expected_out}")
        
        try:
            # Write input to DUT
            await write_input_array(dut, inp)
            
            if is_seq:
                # Sequential processing
                dut.input_len.value = len(inp)
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                await wait_for_done(dut)
                
                # Read output
                result = await read_output_array(dut)
                output_len = safe_int(dut.output_len.value)
                
                cocotb.log.info(f"  Result: {result}")
                cocotb.log.info(f"  Output length: {output_len}")
                
                # Verify output length
                if output_len != len(expected_out):
                    raise TestFailure(f"Output length mismatch: expected {len(expected_out)}, got {output_len}")
                
                # Verify output values
                if result != expected_out:
                    raise TestFailure(f"Output mismatch: expected {expected_out}, got {result}")
                
                # Verify done signal timing
                if not is_value_defined(dut.done.value):
                    raise TestFailure("Done signal undefined")
                if int(dut.done.value) != 1:
                    raise TestFailure("Done signal not high when processing complete")
                
                # Wait a cycle to ensure done is only high for one cycle
                await RisingEdge(dut.clk)
                if int(dut.done.value) == 1:
                    raise TestFailure("Done signal stayed high for more than one cycle")
                
            else:
                # Combinational logic
                await Timer(100, units='ns')
                
                # Read output
                result = await read_output_array(dut)
                output_len = safe_int(dut.output_len.value)
                
                cocotb.log.info(f"  Result: {result}")
                cocotb.log.info(f"  Output length: {output_len}")
                
                # Verify output length
                if output_len != len(expected_out):
                    raise TestFailure(f"Output length mismatch: expected {len(expected_out)}, got {output_len}")
                
                # Verify output values
                if result != expected_out:
                    raise TestFailure(f"Output mismatch: expected {expected_out}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS\n")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}\n")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed out of {passed + failed}")
    else:
        cocotb.log.info(f"All {passed} tests passed!")
