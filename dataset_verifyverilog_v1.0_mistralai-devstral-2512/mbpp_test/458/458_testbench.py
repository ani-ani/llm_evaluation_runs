import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_rectangle_area(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut, cycles=2)
    
    # Test cases
    test_cases = [
        (10, 20, 200, "10x20 area"),
        (10, 5, 50, "10x5 area"),
        (4, 2, 8, "4x2 area"),
        (255, 255, 65025, "Max values"),
        (0, 50, 0, "Zero length"),
        (50, 0, 0, "Zero width"),
        (1, 1, 1, "Unit square"),
        (200, 100, 20000, "Larger values"),
        (255, 1, 255, "Max length, min width"),
        (1, 255, 255, "Min length, max width")
    ]
    
    passed = 0
    failed = 0
    
    for i, (length, width, expected_area, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - length={length}, width={width}")
        
        try:
            # Clamp inputs to 8-bit
            length_clamped = clamp_to_width(length, 8)
            width_clamped = clamp_to_width(width, 8)
            
            # Set inputs
            dut.length.value = length_clamped
            dut.width.value = width_clamped
            
            # Pulse start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, max_cycles=100)
            
            # Read result
            if not is_value_defined(dut.area.value):
                raise TestFailure("Area result undefined")
            
            actual_area = int(dut.area.value)
            
            # Verify
            if actual_area != expected_area:
                raise TestFailure(
                    f"Expected {expected_area}, got {actual_area} "
                    f"(length={length_clamped}, width={width_clamped})"
                )
            
            passed += 1
            cocotb.log.info(f"  PASS: area={actual_area}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Small delay between tests
        await Timer(100, units='ns')
    
    # Summary
    if failed:
        raise TestFailure(f"{failed} out of {len(test_cases)} tests failed")
    else:
        cocotb.log.info(f"All {passed} tests passed")
