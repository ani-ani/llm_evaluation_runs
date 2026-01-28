import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers
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

DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 1000

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def send_strings(dut, s_str, c_str):
    # Encode strings into array indices 0..len-1, 0 elsewhere
    s_arr = [ord(c) for c in s_str]
    c_arr = [ord(c) for c in c_str]
    
    # Pad to 16 elements
    s_arr.extend([0] * (16 - len(s_arr)))
    c_arr.extend([0] * (16 - len(c_arr)))
    
    # Assign individual signals
    for i in range(16):
        # Check if s_chars array exists
        if has_signal(dut, f's_chars_{i}'):
            getattr(dut, f's_chars_{i}').value = clamp_to_width(s_arr[i], DATA_WIDTH)
        else:
            # Assume packed or vector array, though prompt specifies 16x8-bit array
            # If it's a packed signal, we would pack it, but standard Verilog prompts usually
            # specify individual ports or unpacked arrays. 
            # Here we assume individual ports s_chars_0, s_chars_1... based on spec naming convention
            pass
            
    for i in range(16):
        if has_signal(dut, f'c_chars_{i}'):
            getattr(dut, f'c_chars_{i}').value = clamp_to_width(c_arr[i], DATA_WIDTH)

    # Set lengths
    if has_signal(dut, 's_len'):
        dut.s_len.value = clamp_to_width(len(s_str), 4)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_reverse_delete(dut):
    # Start clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic assumed
        await Timer(100, units='ns')

    test_cases = [
        ("abcde", "ae", "bcd", False),
        ("abcdef", "b", "acdef", False),
        ("abcdedcba", "ab", "cdedc", True),
        ("dwik", "w", "dik", False),
        ("a", "a", "", True),
        ("abcdedcba", "", "abcdedcba", True),
        ("abcdedcba", "v", "abcdedcba", True),
        ("vabba", "v", "abba", True),
        ("mamma", "mia", "", True)
    ]

    passed = 0
    failed = 0

    for i, (s_in, c_in, expected_res_str, expected_pal) in enumerate(test_cases):
        cocotb.log.info(f"Running test {i+1}: s='{s_in}', c='{c_in}'")
        
        try:
            # 1. Send Inputs
            await send_strings(dut, s_in, c_in)
            
            if has_signal(dut, 'clk'):
                # Sequence
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational - wait a bit for propagation
                await Timer(10, units='ns')

            # 2. Read Outputs
            if not is_value_defined(dut.result_len.value):
                raise TestFailure("result_len is undefined")
            
            result_len = int(dut.result_len.value)
            
            # Read result chars
            res_chars = []
            for k in range(16):
                if has_signal(dut, f'result_chars_{k}'):
                    val = int(getattr(dut, f'result_chars_{k}').value)
                    if k < result_len:
                        res_chars.append(chr(val))
                else:
                     # Fallback if signal name is different (e.g. vector array access)
                     # But standard prompt usually implies individual ports for 16x8
                     pass
            
            # Construct string
            actual_res_str = "".join(res_chars)
            
            # Check palindrome
            if not is_value_defined(dut.is_palindrome.value):
                raise TestFailure("is_palindrome is undefined")
            is_pal = bool(int(dut.is_palindrome.value))
            
            # 3. Verify
            if actual_res_str != expected_res_str:
                raise TestFailure(f"Result string mismatch: expected '{expected_res_str}', got '{actual_res_str}'")
            
            if is_pal != expected_pal:
                raise TestFailure(f"Palindrome mismatch: expected {expected_pal}, got {is_pal}")
                
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"Test {i+1} FAILED: {e}")
            failed += 1
            
    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All tests passed: {passed}")
