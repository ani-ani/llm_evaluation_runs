import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import math

def float_to_q16(value):
    """Convert float to Q16.16 fixed-point representation"""
    return int(value * 65536) & 0xFFFF

def q16_to_float(q16_val):
    """Convert Q16.16 to float"""
    if q16_val == 0xFFFF:
        return -1.0
    return q16_val / 65536.0

def fixed_mul(a, b):
    """Multiply two Q16.16 numbers"""
    return ((a * b) >> 16) & 0xFFFF

@cocotb.test()
async def test_skiing_probability_basic(dut):
    """Test basic skiing scenario with 2 cabins"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test case 1: 2 cabins, 1 edge with probability 0.5
    # Edge: 0 -> 1 with w=0.5, so success prob = 0.5
    dut.max_k.value = 1
    dut.edge_valid.value = 1  # Only edge 0
    dut.edge_src[0].value = 0
    dut.edge_dst[0].value = 1
    dut.edge_prob[0].value = float_to_q16(0.5)
    
    # Other edges invalid
    for i in range(1, 4):
        dut.edge_valid[i].value = 0
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    timeout = 0
    while not dut.done.value and timeout < 300:
        await RisingEdge(dut.clk)
        timeout += 1
    
    # Check results
    p0 = q16_to_float(int(dut.result_p0.value))
    p1 = q16_to_float(int(dut.result_p1.value))
    
    print(f"Test 1: p0={p0:.9f}, p1={p1:.9f}")
    assert abs(p0 - 0.5) < 0.001, f"Expected 0.5, got {p0}"
    assert abs(p1 - 1.0) < 0.001, f"Expected 1.0, got {p1}"
    print("Test 1 passed: 2/2")

@cocotb.test()
async def test_skiing_probability_two_edges(dut):
    """Test with two edges in series"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # 3 cabins (0,1,2), edges: 0->1 (prob 0.8), 1->2 (prob 0.75)
    # Total prob if skiing both: 0.8 * 0.75 = 0.6
    # If walk one edge: 1.0 * 0.75 = 0.75 or 0.8 * 1.0 = 0.8
    # If walk both: 1.0
    dut.max_k.value = 2
    dut.edge_valid.value = 3  # First two edges valid
    
    # Edge 0: 0->1, prob 0.8
    dut.edge_src[0].value = 0
    dut.edge_dst[0].value = 1
    dut.edge_prob[0].value = float_to_q16(0.8)
    
    # Edge 1: 1->2, prob 0.75  
    dut.edge_src[1].value = 1
    dut.edge_dst[1].value = 2
    dut.edge_prob[1].value = float_to_q16(0.75)
    
    # Invalid edges
    for i in range(2, 4):
        dut.edge_valid[i].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 300:
        await RisingEdge(dut.clk)
        timeout += 1
    
    p0 = q16_to_float(int(dut.result_p0.value))
    p1 = q16_to_float(int(dut.result_p1.value))
    p2 = q16_to_float(int(dut.result_p2.value))
    
    print(f"Test 2: p0={p0:.9f}, p1={p1:.9f}, p2={p2:.9f}")
    # p0: only skiing possible, must take both edges: 0.8*0.75=0.6
    assert abs(p0 - 0.6) < 0.001, f"Expected 0.6, got {p0}"
    # p1: can walk one edge, max(0.8*1.0, 1.0*0.75) = max(0.8, 0.75) = 0.8
    assert abs(p1 - 0.8) < 0.001, f"Expected 0.8, got {p1}"
    # p2: can walk both: 1.0
    assert abs(p2 - 1.0) < 0.001, f"Expected 1.0, got {p2}"
    print("Test 2 passed: 3/3")

@cocotb.test()
async def test_skiing_probability_impossible(dut):
    """Test impossible path (no valid edges forward)"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # 3 cabins, but no edges (impossible to reach cabin 2)
    dut.max_k.value = 2
    dut.edge_valid.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 300:
        await RisingEdge(dut.clk)
        timeout += 1
    
    p0 = q16_to_float(int(dut.result_p0.value))
    p1 = q16_to_float(int(dut.result_p1.value))
    p2 = q16_to_float(int(dut.result_p2.value))
    
    print(f"Test 3: p0={p0:.9f}, p1={p1:.9f}, p2={p2:.9f}")
    assert p0 == -1.0, f"Expected -1.0 for impossible, got {p0}"
    assert p1 == -1.0, f"Expected -1.0 for impossible, got {p1}"
    assert p2 == -1.0, f"Expected -1.0 for impossible, got {p2}"
    print("Test 3 passed: 3/3")

@cocotb.test()
async def test_skiing_probability_all_walks(dut):
    """Test all walking paths"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # 2 cabins, edge 0->1 with w=0.25 (prob=0.75)
    # Expected: p0=0.75, p1=1.0
    dut.max_k.value = 1
    dut.edge_valid.value = 1
    dut.edge_src[0].value = 0
    dut.edge_dst[0].value = 1
    dut.edge_prob[0].value = float_to_q16(0.75)
    
    for i in range(1, 4):
        dut.edge_valid[i].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 300:
        await RisingEdge(dut.clk)
        timeout += 1
    
    p0 = q16_to_float(int(dut.result_p0.value))
    p1 = q16_to_float(int(dut.result_p1.value))
    
    print(f"Test 4: p0={p0:.9f}, p1={p1:.9f}")
    assert abs(p0 - 0.75) < 0.001, f"Expected 0.75, got {p0}"
    assert abs(p1 - 1.0) < 0.001, f"Expected 1.0, got {p1}"
    print("Test 4 passed: 2/2")
    print("
All tests completed successfully!")