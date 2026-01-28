import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_signed(v, bits):
    limit = 1 << (bits - 1)
    if v >= limit: return limit - 1
    if v < -limit: return -limit
    return v

def to_signed(val, bits):
    # Convert python int (possibly negative) to unsigned representation for HDL
    # Or just assign directly if using signed attribute
    return val

# Reference Python Logic for correctness
def python_solve(x1, y1, x2, y2, lines):
    count = 0
    for a, b, c in lines:
        val1 = a * x1 + b * y1 + c
        val2 = a * x2 + b * y2 + c
        if (val1 < 0 and val2 > 0) or (val1 > 0 and val2 < 0):
            count += 1
    return count

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_crazy_town(dut):
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.line_valid.value = 0
    dut.line_end.value = 0
    dut.x1.value = 0
    dut.y1.value = 0
    dut.x2.value = 0
    dut.y2.value = 0
    dut.line_a.value = 0
    dut.line_b.value = 0
    dut.line_c.value = 0
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Cases
    test_sets = [
        {
            "x1": 1, "y1": 1, "x2": -1, "y2": -1,
            "lines": [(0, 1, 0), (1, 0, 0)], # Vertical and Horizontal lines
            "expected": 2
        },
        {
            "x1": 1, "y1": 1, "x2": -1, "y2": -1,
            "lines": [(1, 0, 0), (0, 1, 0), (1, 1, -3)],
            "expected": 2
        },
        {
            "x1": 0, "y1": 1, "x2": 2, "y2": 2,
            "lines": [(1, 1, 2)],
            "expected": 0
        },
        {
            "x1": 100000, "y1": 100000, "x2": -100000, "y2": 100000,
            "lines": [(10000, 0, 7)],
            "expected": 1
        }
    ]

    for i, ts in enumerate(test_sets):
        dut._log.info(f"Running Test Case {i+1}")
        
        # Calculate expected in Python
        expected = ts["expected"]
        
        # Set Coordinates (static for the transaction)
        dut.x1.value = clamp_to_signed(ts["x1"], 32)
        dut.y1.value = clamp_to_signed(ts["y1"], 32)
        dut.x2.value = clamp_to_signed(ts["x2"], 32)
        dut.y2.value = clamp_to_signed(ts["y2"], 32)
        
        # Start Signal
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Stream Lines
        lines = ts["lines"]
        n = len(lines)
        
        for idx, (a, b, c) in enumerate(lines):
            # Inputs
            dut.line_a.value = clamp_to_signed(a, 32)
            dut.line_b.value = clamp_to_signed(b, 32)
            dut.line_c.value = clamp_to_signed(c, 32)
            dut.line_valid.value = 1
            dut.line_end.value = 1 if (idx == n - 1) else 0
            
            await RisingEdge(dut.clk)
            
            # Clear valid after cycle (unless we want to hold it)
            dut.line_valid.value = 0
            dut.line_end.value = 0

        # Wait for done
        max_cycles = 20
        done = False
        for _ in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            raise TestFailure(f"Test {i+1}: Module did not assert done")
            
        # Check result
        result = int(dut.step_count.value)
        if result != expected:
            raise TestFailure(f"Test {i+1}: Expected {expected}, got {result}")
            
        dut._log.info(f"Test {i+1} Passed: {result}")
