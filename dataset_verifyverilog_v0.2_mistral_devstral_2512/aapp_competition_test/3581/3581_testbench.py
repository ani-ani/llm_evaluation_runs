import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Fixed point conversion helpers
Q16_SHIFT = 1 << 16

def float_to_q16(x):
    return int(x * Q16_SHIFT) & 0xFFFFFFFF

def q16_to_float(x):
    if x & 0x80000000:
        return -((0x100000000 - x) / Q16_SHIFT)
    return x / Q16_SHIFT

async def load_data(dut, num_holes, payouts, probs):
    """Load payouts and probabilities into DUT"""
    dut.ready_for_input.value = 1
    dut.start.value = 0
    
    # Load payouts
    for i in range(num_holes):
        dut.payouts_in.value = float_to_q16(payouts[i])
        dut.prob_idx.value = 0  # Signal for payout
        await RisingEdge(dut.clk)
        while not dut.ready_for_input.value:
            await RisingEdge(dut.clk)
    
    # Load probabilities (5 values per hole)
    for i in range(num_holes):
        for j in range(5):
            dut.probs_in.value = float_to_q16(probs[i][j])
            dut.prob_idx.value = j  # 0-4 for p0-p4
            await RisingEdge(dut.clk)
            while not dut.ready_for_input.value:
                await RisingEdge(dut.clk)

@cocotb.test()
async def test_arcade_basic(dut):
    """Test with 2-row example"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case: 2 rows
    # Row 1: hole 0 with payout 100
    # Row 2: holes 1,2 with payouts 50, 50
    num_holes = 3
    payouts = [100, 50, 50]
    probs = [
        [0.0, 0.0, 0.45, 0.45, 0.1],
        [0.0, 0.90, 0.0, 0.0, 0.10],
        [0.90, 0.0, 0.0, 0.0, 0.10]
    ]
    
    await load_data(dut, num_holes, payouts, probs)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    timeout = 5000
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Timeout waiting for completion")
    
    # Check result
    result = q16_to_float(dut.expected_value.value)
    expected = 76.31578947368
    
    dut._log.info(f"Result: {result}, Expected: {expected}")
    
    if abs(result - expected) > 0.001:
        raise TestFailure(f"Result mismatch: {result} vs {expected}")

@cocotb.test()
async def test_arcade_4rows(dut):
    """Test with 4-row example"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # 4 rows, 10 holes
    num_holes = 10
    payouts = [40, 30, 30, 40, 20, 40, 50, 30, 30, 50]
    probs = [
        [0.0, 0.0, 0.45, 0.45, 0.1],
        [0.0, 0.3, 0.3, 0.3, 0.1],
        [0.3, 0.0, 0.3, 0.3, 0.1],
        [0.0, 0.3, 0.3, 0.3, 0.1],
        [0.2, 0.2, 0.2, 0.2, 0.2],
        [0.3, 0.0, 0.3, 0.3, 0.1],
        [0.0, 0.8, 0.0, 0.0, 0.2],
        [0.4, 0.4, 0.0, 0.0, 0.2],
        [0.4, 0.4, 0.0, 0.0, 0.2],
        [0.8, 0.0, 0.0, 0.0, 0.2]
    ]
    
    await load_data(dut, num_holes, payouts, probs)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 10000
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Timeout")
    
    result = q16_to_float(dut.expected_value.value)
    expected = 32.6405451448
    
    dut._log.info(f"Result: {result}, Expected: {expected}")
    
    if abs(result - expected) > 0.001:
        raise TestFailure(f"Result mismatch: {result} vs {expected}")

@cocotb.test()
async def test_edge_case_single_hole(dut):
    """Test with 1 hole (N=1)"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    num_holes = 1
    payouts = [42]
    probs = [[0.0, 0.0, 0.0, 0.0, 1.0]]  # Falls immediately
    
    await load_data(dut, num_holes, payouts, probs)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 1000
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Timeout")
    
    result = q16_to_float(dut.expected_value.value)
    expected = 42.0
    
    dut._log.info(f"Result: {result}, Expected: {expected}")
    
    if abs(result - expected) > 0.001:
        raise TestFailure(f"Result mismatch: {result} vs {expected}")

@cocotb.test()
async def test_negative_payouts(dut):
    """Test with negative payouts"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    num_holes = 2
    payouts = [100, -50]
    probs = [
        [0.0, 0.0, 0.0, 0.5, 0.5],  # 50% chance to go to hole 1 (index 1), 50% to drop
        [0.0, 0.0, 0.0, 0.0, 1.0]   # Drops immediately
    ]
    
    await load_data(dut, num_holes, payouts, probs)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 1000
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Timeout")
    
    result = q16_to_float(dut.expected_value.value)
    # E[0] = 100*0.5 + E[1]*0.5 = 50 + (-50)*0.5 = 50 - 25 = 25
    expected = 25.0
    
    dut._log.info(f"Result: {result}, Expected: {expected}")
    
    if abs(result - expected) > 0.001:
        raise TestFailure(f"Result mismatch: {result} vs {expected}")

@cocotb.test()
async def test_high_bounce_probability(dut):
    """Test with high bounce probability"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    num_holes = 2
    payouts = [10, 5]
    probs = [
        [0.0, 0.0, 0.0, 0.95, 0.05],  # 95% go to hole 1
        [0.0, 0.0, 0.0, 0.0, 1.0]     # Drops immediately
    ]
    
    await load_data(dut, num_holes, payouts, probs)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 1000
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Timeout")
    
    result = q16_to_float(dut.expected_value.value)
    # E[0] = 10*0.05 + E[1]*0.95 = 0.5 + 5*0.95 = 0.5 + 4.75 = 5.25
    expected = 5.25
    
    dut._log.info(f"Result: {result}, Expected: {expected}")
    
    if abs(result - expected) > 0.001:
        raise TestFailure(f"Result mismatch: {result} vs {expected}")