import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
MAX_DIGITS = 24
MAX_RESULT_LEN = 48
DATA_WIDTH = 8
TARGET_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 10000

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

# ASCII helpers
def to_ascii_arr(s, max_len):
    arr = [0] * max_len
    for i, c in enumerate(s):
        if i < max_len:
            arr[i] = ord(c)
    return arr

def from_ascii_arr(arr, length):
    return ''.join(chr(arr[i]) for i in range(length) if arr[i] != 0)

# Parse A=S input
def parse_input(input_str):
    parts = input_str.strip().split('=')
    a_str = parts[0]
    s_val = int(parts[1])
    digits = [int(c) for c in a_str]
    return digits, s_val, a_str + "=" + str(s_val)

@cocotb.test(timeout_time=10, timeout_unit='s')
async def test_partition_addition(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        # Clear inputs
        if has_signal(dut, 'len_in'):
            dut.len_in.value = 0
        if has_signal(dut, 'target_sum'):
            dut.target_sum.value = 0
        if has_signal(dut, 'digits_in'):
            for i in range(MAX_DIGITS):
                dut.digits_in[i].value = 0
                
        for _ in range(2):
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
    else:
        await Timer(100, units='ns')

    # Test Cases
    test_inputs = [
        "143175=120",
        "5025=30",
        "999899=125"
    ]
    
    expected_outputs = [
        "14+31+75=120",
        "5+025=30",
        "9+9+9+89+9=125"
    ]

    for idx, inp_str in enumerate(test_inputs):
        cocotb.log.info(f"Running test case {idx+1}: {inp_str}")
        
        digits, target, expected_full = parse_input(inp_str)
        exp_out_str = expected_outputs[idx]
        
        # Load Inputs
        if has_signal(dut, 'digits_in'):
            for i in range(MAX_DIGITS):
                val = digits[i] if i < len(digits) else 0
                dut.digits_in[i].value = clamp_to_width(val, DATA_WIDTH)
                
        if has_signal(dut, 'len_in'):
            dut.len_in.value = clamp_to_width(len(digits), 5)
        if has_signal(dut, 'target_sum'):
            dut.target_sum.value = clamp_to_width(target, TARGET_WIDTH)
        
        # Start
        if has_signal(dut, 'start'):
            dut.start.value = 1
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            dut.start.value = 0
            
        # Wait for Done
        done_found = False
        if has_signal(dut, 'done'):
            for _ in range(MAX_CYCLES):
                if has_signal(dut, 'clk'):
                    await RisingEdge(dut.clk)
                else:
                    await Timer(CLK_NS, units='ns')
                
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done_found = True
                    break
        else:
            # Combinational logic fallback
            await Timer(500, units='ns')
            done_found = True
            
        if not done_found:
            raise TestFailure(f"Timeout waiting for done signal in test {idx+1}")
            
        # Read Result
        res_len = 0
        if has_signal(dut, 'result_len'):
            res_len = int(dut.result_len.value)
        else:
            # Fallback: heuristic or assume max length if signal missing
            res_len = len(exp_out_str)
            
        # Read result string array
        res_chars = []
        res_str_signal = None
        if has_signal(dut, 'result_str'):
            res_str_signal = dut.result_str
        
        for i in range(MAX_RESULT_LEN):
            char_val = 0
            if res_str_signal is not None:
                char_val = int(res_str_signal[i].value)
            
            if char_val != 0:
                res_chars.append(chr(char_val))
            elif i < res_len:
                 # If length is defined, include zeros inside length
                 pass
        
        actual_str = ''.join(res_chars)
        
        # Compare
        # If actual string matches expected, good.
        # If not, verify the mathematical correctness manually.
        
        if actual_str == exp_out_str:
            cocotb.log.info(f"Passed: {actual_str}")
        else:
            # Verify logic manually
            parts = actual_str.split('=')
            if len(parts) != 2:
                 raise TestFailure(f"Invalid output format: {actual_str}")
            
            lhs, rhs_str = parts
            try:
                rhs_val = int(rhs_str)
            except ValueError:
                 raise TestFailure(f"RHS not a number: {rhs_str}")
                 
            # Calculate LHS sum
            terms = lhs.split('+')
            lhs_sum = 0
            try:
                for term in terms:
                    lhs_sum += int(term)
            except ValueError:
                 raise TestFailure(f"Invalid term in LHS: {terms}")
            
            if lhs_sum != target:
                 raise TestFailure(f"Sum mismatch for {inp_str}: {actual_str} (Sum: {lhs_sum}, Target: {target})")
            
            # Sum is correct, check format
            if not all(c.isdigit() or c in '+=' for c in actual_str):
                 raise TestFailure(f"Invalid characters in result: {actual_str}")
                 
            cocotb.log.warning(f"Alternative solution found: {actual_str} (Correct sum)")