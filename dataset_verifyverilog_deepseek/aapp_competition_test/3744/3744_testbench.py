import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_team_selector(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1 (adapted from original input 4)
    a = [10, 8, 8, 3, 0, 0, 0, 0]
    b = [10, 7, 9, 4, 0, 0, 0, 0]
    expected_strength = 31
    expected_prog = 0b00000011  # Students 1 & 2
    expected_sport = 0b00001100  # Students 3 & 4
    
    # Load inputs
    for i in range(8):
        dut.a[i].value = a[i]
        dut.b[i].value = b[i]
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    # Verify outputs
    assert dut.done.value == 1, "Test 1: Done not asserted"
    assert dut.max_strength.value == expected_strength, f"Test 1: Strength {dut.max_strength.value} != {expected_strength}"
    assert dut.prog_team.value == expected_prog, f"Test 1: Prog team {bin(dut.prog_team.value)} != {bin(expected_prog)}"
    assert dut.sport_team.value == expected_sport, f"Test 1: Sport team {bin(dut.sport_team.value)} != {bin(expected_sport)}"
    
    # Test case 2 (simple case)
    a = [100, 101, 0, 0, 0, 0, 0, 0]
    b = [1, 100, 0, 0, 0, 0, 0, 0]
    expected_strength = 200
    expected_prog = 0b00000001  # Student 1
    expected_sport = 0b00000010  # Student 2
    
    # Reset between tests
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Load inputs
    for i in range(8):
        dut.a[i].value = a[i]
        dut.b[i].value = b[i]
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    # Verify outputs
    assert dut.done.value == 1, "Test 2: Done not asserted"
    assert dut.max_strength.value == expected_strength, f"Test 2: Strength {dut.max_strength.value} != {expected_strength}"
    assert dut.prog_team.value == expected_prog, f"Test 2: Prog team {bin(dut.prog_team.value)} != {bin(expected_prog)}"
    assert dut.sport_team.value == expected_sport, f"Test 2: Sport team {bin(dut.sport_team.value)} != {bin(expected_sport)}"
    
    dut._log.info("2/2 tests passed")