import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import string

DATA_WIDTH, ARRAY_SIZE, CLK_NS, MAX_CYCLES = 8, 16, 10, 500

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_string(dut, str_num, chars, str_len):
    """Write characters to the HDL input array"""
    # Write length
    if str_num == 1:
        dut.str1_len.value = clamp_to_width(str_len, 4)
        # Write characters
        for i in range(min(str_len, 16)):
            char_val = ord(chars[i])
            getattr(dut, f'str1_char_{i}').value = clamp_to_width(char_val, 8)
        # Zero remaining positions
        for i in range(str_len, 16):
            getattr(dut, f'str1_char_{i}').value = 0
    else:
        dut.str2_len.value = clamp_to_width(str_len, 4)
        for i in range(min(str_len, 16)):
            char_val = ord(chars[i])
            getattr(dut, f'str2_char_{i}').value = clamp_to_width(char_val, 8)
        for i in range(str_len, 16):
            getattr(dut, f'str2_char_{i}').value = 0

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_match_parens(dut):
    # Check if module has sequential logic
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Define test cases: (str1, str2, expected_result)
    test_cases = [
        ("()(", ")", 'Yes'),
        (")", ")", 'No'),
        ("(()(())", "())())", 'No'),
        (")())", "(()()(", 'Yes'),
        ("(())))", "(()())((", 'Yes'),
        ("()", "())", 'No'),
        ("(()(", "()))()", 'Yes'),
        ("(((", "((())", 'No'),
        (")(", "(()(", 'No'),
        (")(", ")(", 'No'),
        ("(", ")", 'Yes'),
        (")", "(", 'Yes')
    ]
    
    passed = 0
    failed = 0
    
    for i, (str1, str2, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: '{str1}' + '{str2}' = {expected}")
        try:
            # Write strings to HDL
            await write_string(dut, 1, str1, len(str1))
            await write_string(dut, 2, str2, len(str2))
            
            # Start processing
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
            
            result_val = int(dut.result.value)
            expected_val = 1 if expected == 'Yes' else 0
            
            if result_val != expected_val:
                raise TestFailure(f"Expected {expected_val}, got {result_val}")
            
            passed += 1
            cocotb.log.info(f"  PASS: result={result_val}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
            
    if failed:
        raise TestFailure(f"{failed} tests failed out of {len(test_cases)}")
    
    cocotb.log.info(f"All tests passed: {passed}/{len(test_cases)}")