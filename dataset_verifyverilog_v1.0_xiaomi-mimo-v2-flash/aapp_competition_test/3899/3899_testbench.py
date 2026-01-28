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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=2000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_optimization(dut):
    # Setup clock
    CLK_NS = 10
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    # Test cases
    test_cases = [
        ([8, 10, 9, 9, 8, 10], [1, 1, 1, 1, 1, 1], 6, 9000),
        ([8, 10, 9, 9, 8, 10], [1, 10, 5, 5, 1, 10], 6, 1160),
        ([1], [100], 1, 10),
        ([100000000], [1], 1, 100000000000),
    ]
    
    for i, (powers, procs, n, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n}")
        try:
            # Set inputs
            if has_signal(dut, 'n'):
                dut.n.value = clamp_to_width(n, 6)
            
            # Set arrays - individual assignment
            if hasattr(dut, 'power'):
                for j in range(min(n, 50)):
                    # Scale power by 1000 for internal precision
                    val = clamp_to_width(powers[j] * 1000, 24)  # 24 bits for scaled power
                    dut.power[j].value = val
            elif hasattr(dut, 'power_0'):  # Individual ports
                for j in range(min(n, 50)):
                    val = clamp_to_width(powers[j] * 1000, 24)
                    getattr(dut, f'power_{j}').value = val
            
            if hasattr(dut, 'processors'):
                for j in range(min(n, 50)):
                    val = clamp_to_width(procs[j], 8)
                    dut.processors[j].value = val
            elif hasattr(dut, 'processors_0'):
                for j in range(min(n, 50)):
                    val = clamp_to_width(procs[j], 8)
                    getattr(dut, f'processors_{j}').value = val
            
            # Start
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational
                await Timer(1000, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"PASS: Got {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            raise
