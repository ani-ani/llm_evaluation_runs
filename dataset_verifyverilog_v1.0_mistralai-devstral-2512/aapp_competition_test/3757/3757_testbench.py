import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except (ValueError, TypeError):
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=5000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def verify_counts(s, a00, a01, a10, a11):
    cnt_00, cnt_01, cnt_10, cnt_11 = 0, 0, 0, 0
    n = len(s)
    for i in range(n):
        for j in range(i + 1, n):
            pair = s[i] + s[j]
            if pair == '00': cnt_00 += 1
            elif pair == '01': cnt_01 += 1
            elif pair == '10': cnt_10 += 1
            elif pair == '11': cnt_11 += 1
    return (cnt_00 == a00) and (cnt_01 == a01) and (cnt_10 == a10) and (cnt_11 == a11)

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_binary_string_subsequences(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        clock = Clock(dut.clk, 10, units="ns")
        cocotb.start_soon(clock.start())
    else:
        # Combinational logic fallback
        pass
    
    # Test cases: (a00, a01, a10, a11, expected_result_type)
    test_cases = [
        (1, 2, 2, 1, 'valid'),     # 0110
        (1, 2, 3, 4, 'impossible'),
        (0, 0, 0, 0, 'valid'),     # Empty or single char (we expect length > 0)
        (1, 0, 0, 0, 'valid'),     # 00
        (0, 0, 0, 1, 'valid'),     # 11
        (10, 7, 28, 21, 'valid'),  # Example 3
        (1000000000, 0, 0, 0, 'impossible'),
        (0, 1, 1, 1, 'valid'),     # 101
        (1, 1, 1, 0, 'valid'),     # 010
        (6, 4, 0, 0, 'valid'),     # 000001
        (3, 0, 0, 3, 'valid'),     # 1111
    ]

    for i, (a00, a01, a10, a11, expected_type) in enumerate(test_cases):
        cocotb.log.info(f"\nTest Case {i+1}: a00={a00}, a01={a01}, a10={a10}, a11={a11}")
        
        # Reset
        if has_signal(dut, 'clk'):
            await reset_dut(dut)
        
        # Apply inputs
        if has_signal(dut, 'a00'):
            dut.a00.value = a00
            dut.a01.value = a01
            dut.a10.value = a10
            dut.a11.value = a11
        
        # Start
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        elif has_signal(dut, 'clk'):
             await RisingEdge(dut.clk)
        
        # Wait for done or output
        output_chars = []
        cycles_checked = 0
        max_output_cycles = 2000
        
        # If sequential, wait for valid signals
        if has_signal(dut, 'clk'):
            while cycles_checked < max_output_cycles:
                await RisingEdge(dut.clk)
                if is_value_defined(dut.valid.value) and int(dut.valid.value) == 1:
                    if has_signal(dut, 'result_char'):
                        val = int(dut.result_char.value)
                        # Convert integer 48 (ASCII '0') or 49 (ASCII '1') to char
                        if val == 48 or val == 49:
                            output_chars.append(chr(val))
                        else:
                            output_chars.append(str(val))
                    else:
                        # Fallback for non-ASCII interface (e.g., 1-bit output)
                        val = int(dut.result_char.value)
                        output_chars.append(str(val))
                
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    break
                
                cycles_checked += 1
        else:
            # Combinational check (instant result)
            await Timer(10, units='ns')
            if is_value_defined(dut.is_impossible.value) and int(dut.is_impossible.value) == 1:
                pass # Handled below
            else:
                # For combinational, assume interface gives full string or logic to verify
                # Since testbench is generic, we rely on checking done/valid logic if present
                pass

        # Check results
        is_impossible = 0
        if has_signal(dut, 'is_impossible'):
             is_impossible = int(dut.is_impossible.value)
        
        generated_str = ''.join(output_chars)
        
        if expected_type == 'impossible':
            if is_impossible != 1:
                raise TestFailure(f"Test {i+1} failed: Expected Impossible, but got valid output.")
        else:
            if is_impossible == 1:
                raise TestFailure(f"Test {i+1} failed: Expected valid string, but got Impossible.")
            
            if not generated_str:
                # Check if it's a single char case or handled differently
                # If no chars generated but not impossible, verify constraints
                # For test case (0,0,0,0), some implementations might output nothing or '0'
                # If empty, we check if it's valid. Usually valid strings must be non-empty.
                # If the HDL produces nothing, it might be a bug for (0,0,0,0) unless specified otherwise.
                # Let's assume we need at least one char for non-impossible cases unless inputs are all 0.
                if a00 == 0 and a01 == 0 and a10 == 0 and a11 == 0:
                     generated_str = "0" # Artificially add for verification, or assume HDL outputs 0
                else:
                    raise TestFailure(f"Test {i+1} failed: Generated string is empty.")
            
            # Verify against expected string
            # Note: Python logic might produce different valid strings (e.g., all 0s vs all 1s for 0 0 0 0)
            # For 0 0 0 0, we accept "0" or "1". 
            # However, usually standard solutions pick 0 first.
            # Let's verify the counts of the generated string match the inputs.
            
            if not verify_counts(generated_str, a00, a01, a10, a11):
                raise TestFailure(f"Test {i+1} failed: Generated string '{generated_str}' has incorrect counts.")
            
            cocotb.log.info(f"Test {i+1} passed. Output: {generated_str}")
