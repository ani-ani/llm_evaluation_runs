import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, Join
from cocotb.result import TestFailure
import random

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_input.value = 0
    dut.a.value = 0
    dut.b.value = 0
    await Timer(10, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

def calculate_expected(n, m, candies):
    # Returns list of expected times for start stations 0 to n-1
    results = []
    for s in range(n):
        max_time = 0
        # Precompute per-station data
        counts = [0] * n
        min_dists = [999] * n # Large number init
        
        for a, b in candies:
            counts[a] += 1
            # Distance from a to b
            d = (b - a) % n
            if d < min_dists[a]:
                min_dists[a] = d
        
        # Calculate time for this start s
        for i in range(n):
            if counts[i] > 0:
                dist_si = (i - s) % n
                time_i = dist_si + min_dists[i] + (counts[i] - 1) * n
                if time_i > max_time:
                    max_time = time_i
        results.append(max_time)
    return results

@cocotb.test()
async def test_toy_train_basic(dut):
    """Test basic functionality with small inputs"""
    # Generate a simple test case
    # n=3, m=3
    # candies: (0->1), (0->1), (1->2)
    n = 3
    m = 3
    candies = [(0, 1), (0, 1), (1, 2)]
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    # Feed candies
    for a, b in candies:
        dut.a.value = a
        dut.b.value = b
        dut.valid_input.value = 1
        await RisingEdge(dut.clk)
        # Wait for handshake if implemented, else just pulse
        # Assuming continuous stream or simple pulse. 
        # Let's check 'busy' signal if exists, or assume we can just update inputs
        # The spec says 'valid_input' high when inputs are valid.
        # We need to ensure the DUT consumes them.
        # Let's wait for 'busy' to go high if it's a handshake
        # If no handshake, we'll just pulse valid for 1 cycle
        dut.valid_input.value = 0
        await Timer(1, units='ns') # Small delay
    
    # Wait a bit
    await RisingEdge(dut.clk)
    
    # Start calculation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Collect outputs
    outputs = []
    # Expect n outputs
    for _ in range(n):
        # Wait for output_valid
        timeout = 0
        while not dut.output_valid.value and timeout < 100:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 100:
            raise TestFailure("Output valid not asserted within 100 cycles")
            
        outputs.append(int(dut.result.value))
        await RisingEdge(dut.clk)
        
    # Calculate expected
    expected = calculate_expected(n, m, candies)
    
    print(f"Calculated: {outputs}")
    print(f"Expected:   {expected}")
    
    if outputs != expected:
        raise TestFailure(f"Mismatch! Got {outputs}, expected {expected}")

@cocotb.test()
async def test_toy_train_start_1(dut):
    """Test case where train starts at station 1, simplified from sample"""
    # Sample 2: n=2, m=3, all 1->2
    n = 2
    m = 3
    candies = [(1, 2)] * 3
    # Convert to 0-indexed for DUT
    candies_idx = [(c[0]-1, c[1]-1) for c in candies]
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    # Feed candies
    for a, b in candies_idx:
        dut.a.value = a
        dut.b.value = b
        dut.valid_input.value = 1
        await RisingEdge(dut.clk)
        dut.valid_input.value = 0
        await Timer(1, units='ns')
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    outputs = []
    for _ in range(n):
        while not dut.output_valid.value:
            await RisingEdge(dut.clk)
        outputs.append(int(dut.result.value))
        await RisingEdge(dut.clk)
        
    # Expected: Start 0 -> 5, Start 1 -> 6
    # Our logic: Start 0 (Station 1): time = 0 (dist to 1) + min_dist 1->2 (1) + (3-1)*2 = 0+1+4=5
    # Start 1 (Station 2): time = dist(2->1) = 1 + 1 + 4 = 6
    expected = [5, 6]
    
    print(f"Calculated: {outputs}")
    print(f"Expected:   {expected}")
    
    if outputs != expected:
        raise TestFailure(f"Mismatch! Got {outputs}, expected {expected}")

@cocotb.test()
async def test_toy_train_edge_case(dut):
    """Test edge case: single station"""
    # n=3, m=1, 1->2
    n = 3
    m = 1
    candies = [(0, 1)]
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    # Feed
    dut.a.value = 0
    dut.b.value = 1
    dut.valid_input.value = 1
    await RisingEdge(dut.clk)
    dut.valid_input.value = 0
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    outputs = []
    for _ in range(n):
        while not dut.output_valid.value:
            await RisingEdge(dut.clk)
        outputs.append(int(dut.result.value))
        await RisingEdge(dut.clk)
    
    # Expected:
    # Start 0: dist(0->0)=0, time=0+1+0=1
    # Start 1: dist(1->0)=2, time=2+1+0=3
    # Start 2: dist(2->0)=1, time=1+1+0=2
    expected = [1, 3, 2]
    
    print(f"Calculated: {outputs}")
    print(f"Expected:   {expected}")
    
    if outputs != expected:
        raise TestFailure(f"Mismatch! Got {outputs}, expected {expected}")
