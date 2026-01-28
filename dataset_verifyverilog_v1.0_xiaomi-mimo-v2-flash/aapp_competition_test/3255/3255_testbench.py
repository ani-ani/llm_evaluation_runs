import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

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

@cocotb.test(timeout_time=100, timeout_unit='ms')
async def test_hopper(dut):
    DATA_WIDTH, N_MAX, CLK_NS, MAX_CYCLES = 16, 16, 10, 1000
    
    # Setup clock if sequential
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        # n, D, M, arr, expected_len
        (8, 3, 1, [1,7,8,2,6,4,3,5], 8),
        (8, 2, 1, [1,7,8,2,6,4,3,5], 3),
        (8, 1, 1, [1,7,8,2,6,4,3,5], 2),
    ]
    
    for i, (n, D, M, arr, expected) in enumerate(test_cases):
        cocotb.log.info(f'Test {i+1}: n={n}, D={D}, M={M}, arr={arr}')
        
        # Write inputs
        dut.n.value = n
        dut.D.value = D
        # Convert M to fixed-point Q8.8
        M_fixed = int(M * 256)
        dut.M.value = clamp_to_width(M_fixed, DATA_WIDTH)
        
        # Write array
        for idx, val in enumerate(arr):
            if idx < N_MAX:
                # Ensure value fits 16-bit signed
                val_clamped = to_signed(val, DATA_WIDTH)
                dut.arr[idx].value = clamp_to_width(val_clamped, DATA_WIDTH)
        
        # Start computation
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            done_found = False
            for _ in range(MAX_CYCLES):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done_found = True
                    break
            
            if not done_found:
                raise TestFailure(f"Timeout waiting for done on test {i+1}")
            
            # Read result
            if has_signal(dut, 'result'):
                result = int(dut.result.value)
                if result != expected:
                    raise TestFailure(f"Test {i+1} failed: expected {expected}, got {result}")
            else:
                raise TestFailure("Result signal not found")
        else:
            await Timer(100, units='ns')
            # For combinational, assume result available
            if has_signal(dut, 'result'):
                result = int(dut.result.value)
                if result != expected:
                    raise TestFailure(f"Test {i+1} failed: expected {expected}, got {result}")
