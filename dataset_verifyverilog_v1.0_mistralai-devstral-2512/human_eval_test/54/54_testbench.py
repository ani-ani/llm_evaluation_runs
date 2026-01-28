import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
MAX_LEN = 16
CLK_NS = 10
MAX_CYCLES = 2000

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

async def wait_for_done(dut, max_cycles=2000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_string(dut, name, string):
    """Write string chars to individual ports and set length"""
    if len(string) > MAX_LEN:
        raise ValueError(f"String too long: {len(string)} > {MAX_LEN}")
    
    # Write characters to individual ports
    for i in range(MAX_LEN):
        port_name = f"{name}_char_{i}"
        if has_signal(dut, port_name):
            if i < len(string):
                char_val = ord(string[i])
                getattr(dut, port_name).value = clamp_to_width(char_val, DATA_WIDTH)
            else:
                getattr(dut, port_name).value = 0
    
    # Set length
    len_port = f"{name}_len"
    if has_signal(dut, len_port):
        getattr(dut, len_port).value = clamp_to_width(len(string), 4)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_same_chars(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (s0, s1, expected_result, description)
    test_cases = [
        ('eabcdzzzz', 'dddzzzzzzzddeddabc', True, "same chars, different order"),
        ('abcd', 'dddddddabc', True, "same chars, repeated"),
        ('dddddddabc', 'abcd', True, "reverse of previous"),
        ('eabcd', 'dddddddabc', False, "extra 'e' in s0"),
        ('abcd', 'dddddddabcf', False, "extra 'f' in s1"),
        ('eabcdzzzz', 'dddzzzzzzzddddabc', False, "different 'z' counts"),
        ('aabb', 'aaccc', False, "different chars"),
        ('', '', True, "empty strings"),
        ('a', 'a', True, "single char match"),
        ('a', 'b', False, "single char mismatch"),
        ('abc', 'cab', True, "permutation"),
        ('aabbc', 'abcbb', False, "different b counts"),
    ]
    
    passed = failed = 0
    
    for i, (s0, s1, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} ('{s0}', '{s1}')")
        try:
            # Write strings to DUT
            await write_string(dut, 's0', s0)
            await write_string(dut, 's1', s1)
            
            # Start computation
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: result={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"  ERROR: {e}")
            failed += 1
    
    cocotb.log.info(f"\nTotal: {passed} passed, {failed} failed")
    if failed:
        raise TestFailure(f"{failed} tests failed")