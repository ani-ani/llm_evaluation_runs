import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
MAX_STR_LEN = 16
CLK_NS = 10
MAX_CYCLES = 1000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'char_valid'): dut.char_valid.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_string_pattern_match(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        ("ac", False, "no b after a"),
        ("dc", False, "no a present"),
        ("abbbba", True, "a followed by multiple b's"),
        ("dsabbbba", True, "pattern in middle"),
        ("asbbbba", False, "a after s then b's - no a before b's"),
        ("abaaa", True, "a followed by b then a's"),
        ("a", False, "single a without b"),
        ("b", False, "single b without a"),
        ("", False, "empty string"),
        ("ab", True, "minimal pattern"),
        ("aaab", False, "a's then b - no a immediately before b"),
    ]
    
    passed = failed = 0
    
    for i, (input_str, expected_match, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description} - input='{input_str}'")
        
        try:
            if is_seq:
                await reset_dut(dut, 1)
                dut.start.value = 1
                if has_signal(dut, 'input_string_len'):
                    dut.input_string_len.value = len(input_str)
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                for j, char in enumerate(input_str):
                    if has_signal(dut, 'input_char'):
                        dut.input_char.value = ord(char)
                    if has_signal(dut, 'char_valid'):
                        dut.char_valid.value = 1
                    await RisingEdge(dut.clk)
                    
                    if has_signal(dut, 'char_valid'):
                        dut.char_valid.value = 0
                    
                    if j < MAX_STR_LEN - 1:
                        await Timer(1, units='ns')
                
                await wait_for_done(dut, MAX_CYCLES)
                
                if not is_value_defined(dut.match.value):
                    raise TestFailure("Match signal undefined")
                
                match_result = int(dut.match.value)
                if match_result != expected_match:
                    raise TestFailure(f"Expected {expected_match}, got {match_result}")
                
                passed += 1
            else:
                raise TestFailure("Sequential signals required")
                
        except TestFailure as e:
            cocotb.log.error(f"FAIL Test {i+1}: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {len(test_cases)}")