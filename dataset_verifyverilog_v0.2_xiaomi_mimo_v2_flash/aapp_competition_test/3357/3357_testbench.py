import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

def calculate_sunlight_python(n, buildings):
    """
    Python reference for adapted logic.
    buildings: list of (x, h)
    Returns list of hours per building.
    """
    results = []
    # Simplified calculation: 
    # Sunlight = 18.0 * (1 - obstruction_factor)
    # Obstruction factor is sum of west and east slopes normalized
    
    for i in range(n):
        x_i, h_i = buildings[i]
        
        # West obstruction: max slope from west buildings to this one
        max_slope_west = 0
        for j in range(i):
            x_j, h_j = buildings[j]
            if h_j > h_i:
                # Building j is taller, casts shadow
                dist = x_i - x_j
                if dist > 0:
                    slope = (h_j - h_i) * 10000 // dist # Scale up for integer math
                    if slope > max_slope_west:
                        max_slope_west = slope
        
        # East obstruction: max slope from this one to east buildings
        max_slope_east = 0
        for j in range(i + 1, n):
            x_j, h_j = buildings[j]
            if h_j > h_i:
                dist = x_j - x_i
                if dist > 0:
                    slope = (h_j - h_i) * 10000 // dist
                    if slope > max_slope_east:
                        max_slope_east = slope
        
        # Simplified hour calculation
        # If slopes are high, hours reduce. Max slope ~10000 for 45 deg approx
        # Let's use: hours = 18 - (slopes / 1000.0)
        # This ensures positive values for valid inputs
        
        total_slope = max_slope_west + max_slope_east
        hours = 18.0 - (total_slope / 1000.0)
        
        if hours < 0:
            hours = 0.0
        
        results.append(hours)
        
    return results

def to_q16_16(value):
    """Convert float to Q16.16 integer representation."""
    return int(value * 65536)

def from_q16_16(value):
    """Convert Q16.16 integer to float."""
    return value / 65536.0

@cocotb.test()
async def test_sunlight_basic(dut):
    """Test basic case with 4 buildings."""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n_valid.value = 0
    for i in range(8):
        dut.x_data[i].value = 0
        dut.h_data[i].value = 0
    
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Sample Input
    # 4
    # 1 1
    # 2 2
    # 3 2
    # 4 1
    buildings = [(1, 1), (2, 2), (3, 2), (4, 1)]
    expected_results = calculate_sunlight_python(4, buildings)
    
    dut.n_valid.value = 4
    dut.x_data[0].value = 1
    dut.h_data[0].value = 1
    dut.x_data[1].value = 2
    dut.h_data[1].value = 2
    dut.x_data[2].value = 3
    dut.h_data[2].value = 2
    dut.x_data[3].value = 4
    dut.h_data[3].value = 1
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1000:
        raise TestFailure("Timeout waiting for done signal")
    
    # Check results
    for i in range(4):
        result_q16 = dut.sun_hours[i].value
        result_float = from_q16_16(int(result_q16))
        expected = expected_results[i]
        
        # Allow 0.5 tolerance due to integer approximations in HDL vs Python
        if abs(result_float - expected) > 0.5:
            raise TestFailure(f"Building {i}: Expected {expected:.4f}, Got {result_float:.4f}")
        
        dut._log.info(f"Building {i}: {result_float:.4f} hours (Expected: {expected:.4f})")

@cocotb.test()
async def test_sunlight_tall_buildings(dut):
    """Test with tall buildings causing shadows."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    # 5
    # 100 50
    # 125 75
    # 150 100
    # 175 125
    # 200 25
    buildings = [(100, 50), (125, 75), (150, 100), (175, 125), (200, 25)]
    expected_results = calculate_sunlight_python(5, buildings)
    
    dut.n_valid.value = 5
    for i, (x, h) in enumerate(buildings):
        dut.x_data[i].value = x
        dut.h_data[i].value = h
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1000:
        raise TestFailure("Timeout in tall buildings test")
    
    for i in range(5):
        result_q16 = dut.sun_hours[i].value
        result_float = from_q16_16(int(result_q16))
        expected = expected_results[i]
        
        dut._log.info(f"Building {i}: {result_float:.4f} hours (Expected: {expected:.4f})")
        
        # Allow larger tolerance for complex shadow interactions
        if abs(result_float - expected) > 1.0:
            raise TestFailure(f"Building {i}: Diff too large {abs(result_float - expected):.4f}")

@cocotb.test()
async def test_sunlight_single_building(dut):
    """Test single building - should get full 18 hours."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    dut.n_valid.value = 1
    dut.x_data[0].value = 500
    dut.h_data[0].value = 100
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    result_q16 = dut.sun_hours[0].value
    result_float = from_q16_16(int(result_q16))
    
    dut._log.info(f"Single building: {result_float:.4f} hours")
    
    # Should be close to 18 (full sun)
    if result_float < 17.0:
        raise TestFailure(f"Single building should get ~18 hours, got {result_float:.4f}")
