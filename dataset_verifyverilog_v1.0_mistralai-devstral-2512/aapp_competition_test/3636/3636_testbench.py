import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 2000

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

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_obstacle_count(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(2): await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational: set inputs and wait
        await Timer(10, units='ns')
    
    # For this benchmark, we test the logic for N=4, M=4, p=999999937
    # Expected output: 79
    
    # Set inputs if present (e.g., n, m as parameters or signals)
    # Assuming module computes for fixed N=4, M=4
    
    if is_seq:
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        for _ in range(MAX_CYCLES):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure("Timeout waiting for done")
    else:
        await Timer(100, units='ns')
    
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result undefined")
    
    result = int(dut.result.value)
    expected = 79  # For N=4, M=4
    
    # Modulo p (999999937) is large, but 79 < p, so direct compare
    if result != expected:
        raise TestFailure(f"Expected {expected}, got {result}")
    
    cocotb.log.info(f"Test passed: result = {result}")
