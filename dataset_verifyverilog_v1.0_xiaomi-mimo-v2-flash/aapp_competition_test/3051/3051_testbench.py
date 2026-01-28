import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_fog_coverage(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.fog_valid.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Data: [day, x1, x2, y1, y2]
    # We generate a scenario where some fogs overlap and some are missed
    test_fogs = [
        (0, 0, 2, 0, 2),  # Missed (first), covers 0,0-2,2
        (1, 1, 3, 1, 3),  # Missed (overlaps but extends), covers 1,1-3,3
        (2, 0, 2, 0, 2),  # Hit (fully covered by previous)
        (3, 5, 7, 5, 7),  # Missed (new area)
        (4, 6, 8, 6, 8),  # Missed (extends area)
    ]
    expected_missed = 4
    
    # Sort by day (simulation requirement)
    test_fogs.sort(key=lambda x: x[0])

    # Start simulation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Stream fogs
    for fog in test_fogs:
        dut.fog_day.value = clamp_to_width(fog[0], 8)
        dut.fog_x1.value = clamp_to_width(fog[1], 4)
        dut.fog_x2.value = clamp_to_width(fog[2], 4)
        dut.fog_y1.value = clamp_to_width(fog[3], 4)
        dut.fog_y2.value = clamp_to_width(fog[4], 4)
        dut.fog_valid.value = 1
        await RisingEdge(dut.clk)
        
        # Wait for handshake acceptance (assuming single cycle for this testbench)
        # In a real scenario, we might check 'ready' signal, but spec implies valid-only stream
        
    dut.fog_valid.value = 0
    
    # Wait for completion
    # In this simplified spec, 'done' is asserted when input stops.
    # We give it a few cycles to process.
    for _ in range(10):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
    
    # Check result
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined")
    
    result = int(dut.result.value)
    if result != expected_missed:
        raise TestFailure(f"Expected {expected_missed} missed fogs, got {result}")
    
    cocotb.log.info(f"Test passed: Total missed fogs = {result}")
