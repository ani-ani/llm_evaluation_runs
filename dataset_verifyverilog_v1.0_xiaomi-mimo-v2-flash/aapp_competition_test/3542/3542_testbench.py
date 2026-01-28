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

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_min_wire_length(dut):
    # Configuration
    CLK_NS = 10
    MAX_CYCLES = 1000
    
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational: just set inputs and wait
        cocotb.log.info("Combinational module detected")
    
    # Test cases from problem
    test_cases = [
        # (N, M, ax1, ay1, ax2, ay2, bx1, by1, bx2, by2, expected_possible, expected_length, description)
        (6, 3, 2, 3, 4, 0, 0, 2, 6, 1, False, 0, "Intersecting paths (IMPOSSIBLE)"),
        (6, 6, 2, 1, 5, 4, 4, 0, 4, 5, True, 15, "Valid paths (15)"),
        # Additional test: Non-intersecting simple paths
        (4, 4, 0, 0, 4, 0, 0, 4, 4, 4, True, 16, "Parallel horizontal lines"),
        # Test crossing but can route around (simplified: assume no crossing allowed)
        (5, 5, 0, 0, 5, 5, 5, 0, 0, 5, False, 0, "Diagonal crossing (IMPOSSIBLE)"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (N, M, ax1, ay1, ax2, ay2, bx1, by1, bx2, by2, exp_possible, exp_len, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Scale to 4-bit (0-8) as per spec, clamp
            dut.ax1.value = clamp_to_width(ax1, 4)
            dut.ay1.value = clamp_to_width(ay1, 4)
            dut.ax2.value = clamp_to_width(ax2, 4)
            dut.ay2.value = clamp_to_width(ay2, 4)
            dut.bx1.value = clamp_to_width(bx1, 4)
            dut.by1.value = clamp_to_width(by1, 4)
            dut.bx2.value = clamp_to_width(bx2, 4)
            dut.by2.value = clamp_to_width(by2, 4)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut, max_cycles=MAX_CYCLES)
            else:
                await Timer(100, units='ns')
            
            # Check results
            if not is_value_defined(dut.possible.value):
                raise TestFailure("'possible' signal undefined")
            
            possible = int(dut.possible.value)
            if possible != exp_possible:
                raise TestFailure(f"Expected possible={exp_possible}, got {possible}")
            
            if possible:
                if not is_value_defined(dut.result.value):
                    raise TestFailure("'result' signal undefined")
                result = int(dut.result.value)
                if result != exp_len:
                    raise TestFailure(f"Expected result={exp_len}, got {result}")
            
            cocotb.log.info(f"PASS: {desc}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    else:
        cocotb.log.info(f"All {passed} tests passed")
