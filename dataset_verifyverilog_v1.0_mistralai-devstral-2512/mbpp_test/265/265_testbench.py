import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

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

def pack_input_array(values, width=8, max_len=16):
    packed = 0
    for i, v in enumerate(values):
        if i >= max_len: break
        packed |= (clamp_to_width(v, width) & ((1<<width)-1)) << (i*width)
    return packed

def unpack_output_array(packed_val, step, expected_len, width=8, max_sub_len=16):
    """
    Unpacks the result vector into a list of lists.
    Input vector is packed as: [SubSeq0, SubSeq1, ... SubSeq7]
    Each SubSeq is 16 elements * 8 bits = 128 bits.
    """
    result = []
    for i in range(step):
        sub_seq = []
        for k in range(max_sub_len):
            # Extract element at position k in sub-sequence i
            bit_offset = (i * (max_sub_len * width)) + (k * width)
            mask = (1 << width) - 1
            val = (packed_val >> bit_offset) & mask
            # We only collect elements that exist based on total length logic
            # But here we just return all extracted values
            sub_seq.append(val)
        result.append(sub_seq)
    return result

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.valid_out.value) and int(dut.valid_out.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_list_split(dut):
    # Setup
    CLK_NS = 10
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test Cases based on prompt
    test_cases = [
        (['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n'], 3),
        ([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], 3),
        (['python', 'java', 'C', 'C++', 'DBMS', 'SQL'], 2)
    ]
    
    # Convert string inputs to bytes or ascii integers for HDL processing
    # Let's map characters to ASCII codes and strings to hashes or just use integers
    # For simplicity in this testbench, we will encode strings as specific integers
    # or just test with the integer test cases and a converted ASCII case.
    
    parsed_cases = []
    # Case 1: Strings -> ASCII of first char (or dummy hash) for simplicity in 8-bit
    # 'a'=97, 'b'=98, etc. Note: 97 fits in 8 bits.
    c1_vals = [ord(s[0]) if isinstance(s, str) else s for s in test_cases[0][0]]
    parsed_cases.append((c1_vals, 3))
    
    # Case 2: Integers (already valid)
    parsed_cases.append((test_cases[1][0], 3))
    
    # Case 3: Strings -> ASCII
    c3_vals = [ord(s[0]) if isinstance(s, str) else s for s in test_cases[2][0]]
    parsed_cases.append((c3_vals, 2))

    for idx, (raw_values, step) in enumerate(parsed_cases):
        length = len(raw_values)
        
        # Log info
        cocotb.log.info(f"\nTest Case {idx+1}: Input {raw_values}, Step {step}")
        
        # Prepare Input
        # Input width 8 bits, max 16 elements
        dut.data_in.value = pack_input_array(raw_values, width=8, max_len=16)
        dut.len.value = length
        dut.step.value = step
        
        # Start
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
        else:
            # Combinational circuit assumed
            await Timer(100, units='ns')
            
        # Read Result
        if not is_value_defined(dut.result_out.value):
            raise TestFailure("Result output is undefined")
            
        packed_result = int(dut.result_out.value)
        
        # Unpack and Verify
        # Logic to verify: 
        # The output is packed. We need to check if the elements are in the correct stride positions.
        # Expected output from Python: [[S[0], S[3], ...], [S[1], S[4], ...], ...]
        
        python_result = [raw_values[i::step] for i in range(step)]
        
        # Extract from packed result
        extracted_result = unpack_output_array(packed_result, step, length, width=8, max_sub_len=16)
        
        # Compare
        for sub_i in range(step):
            expected_sub = python_result[sub_i]
            extracted_sub = extracted_result[sub_i]
            
            # Check elements up to expected length
            for k, expected_val in enumerate(expected_sub):
                # The extracted value at k might be padded if the logic is strict,
                # but typically valid data is at the start.
                actual_val = extracted_sub[k]
                
                # Convert back to signed/unsigned comparison if needed
                # Since we used unsigned ASCII/integers, direct comparison is fine
                if actual_val != expected_val:
                    raise TestFailure(
                        f"Mismatch in Test {idx+1}, Sub-sequence {sub_i}, Pos {k}: "
                        f"Expected {expected_val}, Got {actual_val}"
                    )
                    
        cocotb.log.info(f"Test {idx+1} Passed. Output verification successful.")
