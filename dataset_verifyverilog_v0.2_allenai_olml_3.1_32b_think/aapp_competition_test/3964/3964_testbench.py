import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_good_plans_basic(dut):
    """Test basic case: 3 programmers, 3 lines, 3 bugs, modulo 100, a=[1,1,1] -> 10 ways"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.a_val.value = 0
    dut.a_val_valid.value = 0
    dut.a_val_done.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Parameters
    n = 3
    m = 3
    b = 3
    mod_val = 100
    a_vals = [1, 1, 1]
    
    # Start
    dut.n.value = n
    dut.m.value = m
    dut.b.value = b
    dut.mod_val.value = mod_val
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for wait_for_a
    while not dut.wait_for_a.value:
        await RisingEdge(dut.clk)
    
    # Load programmer values
    for i, val in enumerate(a_vals):
        dut.a_val.value = val
        dut.a_val_valid.value = 1
        dut.a_val_done.value = 1 if i == len(a_vals) - 1 else 0
        await RisingEdge(dut.clk)
        dut.a_val_valid.value = 0
        dut.a_val_done.value = 0
    
    # Wait for computation
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    # Check result
    result = int(dut.result.value)
    expected = 10 % 100
    if result != expected:
        raise TestFailure(f"Result {result} does not match expected {expected}")
    print(f"Test 1 passed: {result} == {expected}")

@cocotb.test()
async def test_good_plans_zero(dut):
    """Test case: 3 programmers, 6 lines, 5 bugs, modulo 1000000007, a=[1,2,3] -> 0 ways"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.a_val.value = 0
    dut.a_val_valid.value = 0
    dut.a_val_done.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    n = 3
    m = 6
    b = 5
    mod_val = 1000000007
    a_vals = [1, 2, 3]
    
    dut.n.value = n
    dut.m.value = m
    dut.b.value = b
    dut.mod_val.value = mod_val
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.wait_for_a.value:
        await RisingEdge(dut.clk)
    
    for i, val in enumerate(a_vals):
        dut.a_val.value = val
        dut.a_val_valid.value = 1
        dut.a_val_done.value = 1 if i == len(a_vals) - 1 else 0
        await RisingEdge(dut.clk)
        dut.a_val_valid.value = 0
        dut.a_val_done.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result = int(dut.result.value)
    expected = 0
    if result != expected:
        raise TestFailure(f"Result {result} does not match expected {expected}")
    print(f"Test 2 passed: {result} == {expected}")

@cocotb.test()
async def test_good_plans_modulo(dut):
    """Test case: 3 programmers, 5 lines, 6 bugs, modulo 11, a=[1,2,1] -> 0 ways"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.a_val.value = 0
    dut.a_val_valid.value = 0
    dut.a_val_done.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    n = 3
    m = 5
    b = 6
    mod_val = 11
    a_vals = [1, 2, 1]
    
    dut.n.value = n
    dut.m.value = m
    dut.b.value = b
    dut.mod_val.value = mod_val
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.wait_for_a.value:
        await RisingEdge(dut.clk)
    
    for i, val in enumerate(a_vals):
        dut.a_val.value = val
        dut.a_val_valid.value = 1
        dut.a_val_done.value = 1 if i == len(a_vals) - 1 else 0
        await RisingEdge(dut.clk)
        dut.a_val_valid.value = 0
        dut.a_val_done.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result = int(dut.result.value)
    expected = 0
    if result != expected:
        raise TestFailure(f"Result {result} does not match expected {expected}")
    print(f"Test 3 passed: {result} == {expected}")

@cocotb.test()
async def test_good_plans_small(dut):
    """Test case: 2 programmers, 3 lines, 3 bugs, modulo 1000, a=[1,2] -> 1 way"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.a_val.value = 0
    dut.a_val_valid.value = 0
    dut.a_val_done.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    n = 2
    m = 3
    b = 3
    mod_val = 1000
    a_vals = [1, 2]
    
    dut.n.value = n
    dut.m.value = m
    dut.b.value = b
    dut.mod_val.value = mod_val
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.wait_for_a.value:
        await RisingEdge(dut.clk)
    
    for i, val in enumerate(a_vals):
        dut.a_val.value = val
        dut.a_val_valid.value = 1
        dut.a_val_done.value = 1 if i == len(a_vals) - 1 else 0
        await RisingEdge(dut.clk)
        dut.a_val_valid.value = 0
        dut.a_val_done.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result = int(dut.result.value)
    expected = 1
    if result != expected:
        raise TestFailure(f"Result {result} does not match expected {expected}")
    print(f"Test 4 passed: {result} == {expected}")

@cocotb.test()
async def test_good_plans_edge_case(dut):
    """Test case: 1 programmer, 1 line, 0 bugs, modulo 1000, a=[0] -> 1 way"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.a_val.value = 0
    dut.a_val_valid.value = 0
    dut.a_val_done.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    n = 1
    m = 1
    b = 0
    mod_val = 1000
    a_vals = [0]
    
    dut.n.value = n
    dut.m.value = m
    dut.b.value = b
    dut.mod_val.value = mod_val
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.wait_for_a.value:
        await RisingEdge(dut.clk)
    
    for i, val in enumerate(a_vals):
        dut.a_val.value = val
        dut.a_val_valid.value = 1
        dut.a_val_done.value = 1 if i == len(a_vals) - 1 else 0
        await RisingEdge(dut.clk)
        dut.a_val_valid.value = 0
        dut.a_val_done.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    result = int(dut.result.value)
    expected = 1
    if result != expected:
        raise TestFailure(f"Result {result} does not match expected {expected}")
    print(f"Test 5 passed: {result} == {expected}")