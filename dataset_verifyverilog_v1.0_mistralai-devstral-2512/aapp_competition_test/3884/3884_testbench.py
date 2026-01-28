import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

DATA_WIDTH = 10
N_MAX = 1000
CLK_NS = 10
MAX_CYCLES = 200000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, int(v)))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_rocket_fuel(dut):
    # Check for clock
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 1
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        await Timer(100, units='ns')

    # Test cases based on problem description
    test_cases = [
        # (n, m, a_list, b_list, expected_result)
        (2, 12, [11, 8], [7, 5], 10.0),
        (3, 1, [1, 4, 1], [2, 5, 3], -1.0),
        (6, 2, [4, 6, 3, 3, 5, 6], [2, 6, 3, 6, 5, 3], 85.48),
        (2, 12, [11, 8], [1, 1], -1.0),
        (2, 1, [2, 2], [2, 2], 3.0),
    ]

    for idx, (n, m, a_list, b_list, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {idx+1}: n={n}, m={m}")
        
        # Check for invalid coefficients (a_i == 1 or b_i == 1)
        impossible = False
        for x in a_list:
            if x == 1:
                impossible = True
                break
        for x in b_list:
            if x == 1:
                impossible = True
                break
        
        # Set inputs
        # We assume the DUT has individual inputs for a and b (e.g., a_0, a_1...) or arrays.
        # Using individual inputs approach as per typical hardware constraints for fixed n.
        for i in range(n):
            if has_signal(dut, f'a_{i}'):
                dut.__setattr__(f'a_{i}', clamp_to_width(a_list[i], DATA_WIDTH))
            elif has_signal(dut, f'a[{i}]'):
                dut.a[i].value = clamp_to_width(a_list[i], DATA_WIDTH)
            
            if has_signal(dut, f'b_{i}'):
                dut.__setattr__(f'b_{i}', clamp_to_width(b_list[i], DATA_WIDTH))
            elif has_signal(dut, f'b[{i}]'):
                dut.b[i].value = clamp_to_width(b_list[i], DATA_WIDTH)
        
        dut.m.value = clamp_to_width(m, DATA_WIDTH)
        
        if is_seq:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done or timeout
            timeout_count = 0
            done = False
            while timeout_count < MAX_CYCLES:
                await RisingEdge(dut.clk)
                timeout_count += 1
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done = True
                    break
            
            if not done:
                raise TestFailure(f"Timeout waiting for done on test {idx+1}")
            
            # Read result
            if not is_value_defined(dut.result.value):
                 raise TestFailure(f"Result undefined on test {idx+1}")
            
            result_raw = int(dut.result.value)
            
            # Interpret result
            if result_raw == 0xFFFFFFFF: # -1 in 32-bit
                result_val = -1.0
            else:
                # Convert Q16.16 to float
                result_val = result_raw / 65536.0
            
        else:
            # Combinational
            await Timer(100, units='ns')
            if not is_value_defined(dut.result.value):
                 raise TestFailure(f"Result undefined on test {idx+1}")
            result_raw = int(dut.result.value)
            if result_raw == 0xFFFFFFFF:
                result_val = -1.0
            else:
                result_val = result_raw / 65536.0

        if abs(result_val - expected) > 1e-4 and (expected >= 0 or result_val >= 0):
            raise TestFailure(f"Test {idx+1} Failed: Expected {expected}, got {result_val}")
        
        cocotb.log.info(f"Test {idx+1} Passed: Result {result_val}")
        
        if is_seq:
            # Reset for next test
            dut.rst_n.value = 0
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            dut.rst_n.value = 1
            await RisingEdge(dut.clk)
