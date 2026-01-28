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

def pack_grid(grid_str):
    """Pack 8x8 grid into 64-bit integer (8 bytes, LSB first)"""
    rows = grid_str.strip().split('\n')
    packed = 0
    for i, row in enumerate(rows[:8]):
        for j, char in enumerate(row[:8]):
            packed |= (ord(char) << (i*64 + j*8))
    return packed

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
        else: await Timer(10, units='ns')
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
    else: await Timer(10, units='ns')

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(10, units='ns')
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_gargoyle_puzzle(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(10, units='ns')
    
    # Test cases: (grid_string, n, m, expected_result, expected_valid, description)
    test_cases = [
        ("/.V.\\\\n./.V.\\n..#..\\n.V.#.\\\\n\\\\.V./", 5, 5, 3, 1, "Sample 1: 3 rotations"),
        ("V...\\\\nH...V", 2, 5, 15, 0, "Sample 2: impossible"),
        ("VV\\\\nVV", 2, 2, 0, 1, "Sample 3: 0 rotations"),
        (".\\\\n.", 1, 1, 0, 1, "1x1 empty"),
        ("V", 1, 1, 0, 1, "1x1 V gargoyle"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (grid_str, n, m, exp_result, exp_valid, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Pack grid into 64-bit input
            packed = pack_grid(grid_str)
            dut.grid_data.value = packed
            if has_signal(dut, 'n'):
                dut.n.value = clamp_to_width(n, 4)
            if has_signal(dut, 'm'):
                dut.m.value = clamp_to_width(m, 4)
            
            if is_seq:
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
            else:
                # Combinational logic
                await Timer(100, units='ns')
            
            # Read results
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            valid = int(dut.valid.value) if has_signal(dut, 'valid') else 1
            
            # Check result
            if exp_valid == 0:
                # Expected impossible: result should be 15 (our error code)
                if result != 15:
                    raise TestFailure(f"Expected impossible (15), got {result}")
            else:
                if result != exp_result:
                    raise TestFailure(f"Expected {exp_result}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: Result={result}, Valid={valid}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Reset for next test
        await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed")
    
    cocotb.log.info(f"All {passed} tests passed!")
