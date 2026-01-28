import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'c_valid'): dut.c_valid.value = 0
    if has_signal(dut, 'c_in'): dut.c_in.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=2000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_remainders(dut):
    # Check necessary signals
    if not (has_signal(dut, 'clk') and has_signal(dut, 'rst_n') and has_signal(dut, 'start')):
        return # Skip non-sequential module
    
    # Setup
    CLK_NS = 10
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)

    # Test cases derived from problem
    test_cases = [
        # (n, k, [c_i], expected_result_str)
        (4, 5, [2, 3, 5, 12], "Yes"),
        (2, 7, [2, 3], "No"),
        (1, 6, [8], "No"),
        (2, 3, [9, 4], "Yes"),
        (4, 16, [19, 16, 13, 9], "Yes"),
        (2, 4, [2, 2], "No"),
        (10, 4, [2]*10, "No"),
        (3, 24, [2, 2, 3], "No"),
        (2, 16, [4, 8], "Yes"),
        (3, 12, [2, 3, 6], "Yes")
    ]

    passed = 0
    failed = 0

    for i, (n_val, k_val, c_list, expected) in enumerate(test_cases):
        # Log test case
        cocotb.log.info(f"Test {i+1}: n={n_val}, k={k_val}, c={c_list}")
        
        # Reset state
        await reset_dut(dut)
        
        # Start sequence
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for ready
        if has_signal(dut, 'ready'):
            for _ in range(100):
                await RisingEdge(dut.clk)
                if int(dut.ready.value) == 1:
                    break
            else:
                raise TestFailure("Module never became ready")
        
        # Stream in n values
        if has_signal(dut, 'n'):
            dut.n.value = clamp_to_width(n_val, 4)
        
        for idx, val in enumerate(c_list):
            # Wait for ready if present
            if has_signal(dut, 'ready'):
                timeout = 0
                while int(dut.ready.value) == 0 and timeout < 50:
                    await RisingEdge(dut.clk)
                    timeout += 1
                if timeout >= 50:
                    raise TestFailure(f"Module not ready for input {idx}")
            
            if has_signal(dut, 'c_valid'):
                dut.c_valid.value = 1
            if has_signal(dut, 'c_in'):
                dut.c_in.value = clamp_to_width(val, 20)
            if has_signal(dut, 'k'):
                dut.k.value = clamp_to_width(k_val, 20)
            
            await RisingEdge(dut.clk)
            
            if has_signal(dut, 'c_valid'):
                dut.c_valid.value = 0
            
            # If stream interface requires specific handshaking, handle it here
            # Currently simple valid pulse assumed
            
            # Wait for next cycle to allow processing
            await RisingEdge(dut.clk)

        # Wait for done
        await wait_for_done(dut)
        
        # Check result
        if has_signal(dut, 'result'):
            res_val = int(dut.result.value)
            exp_val = 1 if expected == "Yes" else 0
            
            if res_val == exp_val:
                passed += 1
            else:
                failed += 1
                raise TestFailure(f"Test {i+1} failed: Expected {exp_val}, got {res_val}")

    if failed > 0:
        raise TestFailure(f"Total {failed} tests failed")
