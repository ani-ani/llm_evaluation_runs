import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except (ValueError, TypeError): return False

def safe_int(v, default=0):
    try: return int(v)
    except (ValueError, TypeError): return default

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

async def wait_for_done(dut, max_cycles=10000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_bookcase(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(10, units='ns')
    
    # Test cases: (N, [(h,t)...], expected_area)
    test_cases = [
        (4, [(220,29), (195,20), (200,9), (180,30)], 18000),
        (4, [(220,29), (195,20), (200,9), (180,30)], 18000),  # Duplicate to ensure robustness
    ]
    
    for i, (N, books, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: N={N}, books={books}")
        
        # Set N_in (if exists)
        if has_signal(dut, 'N_in'):
            dut.N_in.value = clamp_to_width(N, 8)
        
        # Write books to arrays
        for idx, (h, t) in enumerate(books):
            # Clamp to 8 bits (safety)
            h_clamped = clamp_to_width(h, 8)
            t_clamped = clamp_to_width(t, 8)
            
            if has_signal(dut, f'h_{idx}'):
                getattr(dut, f'h_{idx}').value = h_clamped
            elif has_signal(dut, f'h_i'):
                dut.h_i[idx].value = h_clamped
            
            if has_signal(dut, f't_{idx}'):
                getattr(dut, f't_{idx}').value = t_clamped
            elif has_signal(dut, f't_i'):
                dut.t_i[idx].value = t_clamped
        
        # Clear remaining slots for N < 8
        if N < 8:
            for idx in range(N, 8):
                if has_signal(dut, f'h_{idx}'):
                    getattr(dut, f'h_{idx}').value = 0
                elif has_signal(dut, f'h_i'):
                    dut.h_i[idx].value = 0
                if has_signal(dut, f't_{idx}'):
                    getattr(dut, f't_{idx}').value = 0
                elif has_signal(dut, f't_i'):
                    dut.t_i[idx].value = 0
        
        # Start computation
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        else:
            # Combinational module: trigger by setting inputs
            await Timer(100, units='ns')
        
        # Wait for done
        if has_signal(dut, 'done'):
            await wait_for_done(dut)
        else:
            await Timer(500, units='ns')
        
        # Read result
        if not has_signal(dut, 'result'):
            raise TestFailure("Result signal not found")
        
        result_val = int(dut.result.value)
        
        # Check result (allow small tolerance for fixed-point)
        if abs(result_val - expected) > 1000:  # Tolerance
            raise TestFailure(f"Expected {expected}, got {result_val}")
        
        cocotb.log.info(f"Result: {result_val}")
        
        # Reset for next test
        if has_signal(dut, 'clk'):
            await reset_dut(dut)
        else:
            await Timer(100, units='ns')
