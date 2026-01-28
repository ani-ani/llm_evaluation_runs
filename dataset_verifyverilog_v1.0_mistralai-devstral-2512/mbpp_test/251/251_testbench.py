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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

DATA_WIDTH = 8
ARRAY_SIZE_IN = 8
ARRAY_SIZE_OUT = 16
MAX_LEN_IN = 8
MAX_LEN_OUT = 16
CLK_NS = 10
MAX_CYCLES = 100

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_input_array(dut, values):
    """Write values to arr_in[0:7] individually"""
    # Clear all first
    for i in range(ARRAY_SIZE_IN):
        dut.arr_in[i].value = 0
    # Set actual values
    for i, v in enumerate(values):
        if i >= ARRAY_SIZE_IN:
            raise TestFailure(f"Input array size {len(values)} exceeds {ARRAY_SIZE_IN}")
        dut.arr_in[i].value = clamp_to_width(ord(v) if isinstance(v, str) else v, DATA_WIDTH)

async def read_output_array(dut, expected_len):
    """Read values from result[0:15] individually"""
    result = []
    for i in range(ARRAY_SIZE_OUT):
        if i >= expected_len:
            break
        if not is_value_defined(dut.result[i].value):
            raise TestFailure(f"Result[{i}] undefined")
        val = int(dut.result[i].value)
        result.append(val)
    return result

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_insert_element(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (input_list, element_char, expected_list)
    test_cases = [
        (['R', 'G', 'B'], 'c', ['c', 'R', 'c', 'G', 'c', 'B']),
        (['p', 'j'], 'a', ['a', 'p', 'a', 'j']),
        (['h', 's'], 'l', ['l', 'h', 'l', 's']),
        ([], 'x', []),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_list, elem_char, expected_list) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {input_list} + '{elem_char}'")
        
        try:
            # Write inputs
            await write_input_array(dut, input_list)
            dut.len_in.value = len(input_list)
            dut.element.value = clamp_to_width(ord(elem_char) if isinstance(elem_char, str) else elem_char, DATA_WIDTH)
            
            # Start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read results
            expected_len = len(expected_list)
            output_len = int(dut.len_out.value)
            
            # Check length
            if output_len != expected_len:
                raise TestFailure(f"Length mismatch: expected {expected_len}, got {output_len}")
            
            # Check array contents
            result = await read_output_array(dut, expected_len)
            
            # Compare with expected (as ASCII values)
            expected_vals = [ord(c) for c in expected_list] if expected_list else []
            
            if result != expected_vals:
                raise TestFailure(f"Array mismatch:\nExpected: {expected_vals}\nGot: {result}")
            
            cocotb.log.info(f"PASS: {input_list} + '{elem_char}' → {expected_list} (len={expected_len})")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL Test {i+1}: {e}")
            failed += 1
        
        # Reset for next test
        await reset_dut(dut)
    
    # Final report
    cocotb.log.info(f"\n=== RESULTS: {passed} passed, {failed} failed ===")
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")
    else:
        cocotb.log.info("All tests passed!")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Additional edge case tests"""
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Single element test
    dut.arr_in[0].value = ord('A')
    dut.len_in.value = 1
    dut.element.value = ord('!')
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    if int(dut.len_out.value) != 2:
        raise TestFailure(f"Single element length: expected 2, got {int(dut.len_out.value)}")
    
    # Check order
    if is_value_defined(dut.result[0].value) and int(dut.result[0].value) != ord('!'):
        raise TestFailure(f"First output should be '!' got {int(dut.result[0].value)}")
    
    if is_value_defined(dut.result[1].value) and int(dut.result[1].value) != ord('A'):
        raise TestFailure(f"Second output should be 'A' got {int(dut.result[1].value)}")
    
    cocotb.log.info("Edge case: Single element - PASS")