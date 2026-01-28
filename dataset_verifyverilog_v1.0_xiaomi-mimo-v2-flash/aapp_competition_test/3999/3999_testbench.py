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

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_cube_count(dut):
    # Clock and reset
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: Sample input from problem
    # 6 tiles
    tiles = [
        [0, 1, 2, 3],
        [0, 4, 6, 1],
        [1, 6, 7, 2],
        [2, 7, 5, 3],
        [6, 4, 5, 7],
        [4, 0, 3, 5]
    ]
    
    # Write tiles to DUT
    # Assuming interface: tile_colors[400][4] as 10-bit inputs
    for i, tile in enumerate(tiles):
        for j, color in enumerate(tile):
            # Assuming port naming: tile_i_j for tile i, color j
            port_name = f'tile_{i}_{j}'
            if has_signal(dut, port_name):
                getattr(dut, port_name).value = clamp_to_width(color, 10)
    
    # Set tile count
    if has_signal(dut, 'tile_count'):
        dut.tile_count.value = 6
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    done = False
    for _ in range(10000):
        await RisingEdge(dut.clk)
        if has_signal(dut, 'done') and is_value_defined(dut.done.value):
            if int(dut.done.value) == 1:
                done = True
                break
    
    if not done:
        raise TestFailure("Timeout waiting for done signal")
    
    # Read result
    if not has_signal(dut, 'result'):
        raise TestFailure("Result signal not found")
    
    result = int(dut.result.value)
    expected = 1  # From sample output
    
    if result != expected:
        raise TestFailure(f"Expected {expected}, got {result}")
    
    cocotb.log.info(f"Test passed: result = {result}")
    
    # Test case 2: All same colors (should have many cubes)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Write 6 identical tiles with all corners 0
    for i in range(6):
        for j in range(4):
            port_name = f'tile_{i}_{j}'
            if has_signal(dut, port_name):
                getattr(dut, port_name).value = 0
    
    if has_signal(dut, 'tile_count'):
        dut.tile_count.value = 6
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    done = False
    for _ in range(10000):
        await RisingEdge(dut.clk)
        if has_signal(dut, 'done') and is_value_defined(dut.done.value):
            if int(dut.done.value) == 1:
                done = True
                break
    
    if not done:
        raise TestFailure("Timeout on test 2")
    
    result2 = int(dut.result.value)
    # For 6 identical tiles, number of distinct cubes is 1 (all same)
    # But we need to check the expected output
    # From test cases: 6 identical tiles with all 0 colors should give 122880
    expected2 = 122880
    
    if result2 != expected2:
        raise TestFailure(f"Test 2: Expected {expected2}, got {result2}")
    
    cocotb.log.info(f"Test 2 passed: result = {result2}")
    
    # Test case 3: 400 tiles all zeros (edge case)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Write 400 tiles all zeros
    for i in range(400):
        for j in range(4):
            port_name = f'tile_{i}_{j}'
            if has_signal(dut, port_name):
                getattr(dut, port_name).value = 0
    
    if has_signal(dut, 'tile_count'):
        dut.tile_count.value = 400
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    done = False
    for _ in range(100000):  # More cycles for N=400
        await RisingEdge(dut.clk)
        if has_signal(dut, 'done') and is_value_defined(dut.done.value):
            if int(dut.done.value) == 1:
                done = True
                break
    
    if not done:
        raise TestFailure("Timeout on test 3")
    
    result3 = int(dut.result.value)
    expected3 = 673205187207168000  # From test cases
    
    if result3 != expected3:
        raise TestFailure(f"Test 3: Expected {expected3}, got {result3}")
    
    cocotb.log.info(f"Test 3 passed: result = {result3}")
    
    cocotb.log.info("All tests passed!")