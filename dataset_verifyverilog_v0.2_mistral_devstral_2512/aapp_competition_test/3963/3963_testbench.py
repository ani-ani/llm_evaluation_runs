import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def test_coin_ways_basic(dut):
    """Test basic case: 1 coin type, 4 coins, target 2"""
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Load Test 1: n=1, b0=4, m=2
    dut.n.value = 1
    dut.b_0.value = 4
    dut.m.value = 2
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while dut.done.value == 0 and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1, "Did not finish in time"
    assert dut.result.value == 1, f"Expected 1, got {dut.result.value}"
    print("Test 1 Passed")

@cocotb.test()
async def test_coin_ways_two_types(dut):
    """Test case: 2 types, a1=1, b=[4,4], m=2"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # n=2, a1=1, b0=4, b1=4, m=2
    dut.n.value = 2
    dut.a_1.value = 1
    dut.b_0.value = 4
    dut.b_1.value = 4
    dut.m.value = 2
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while dut.done.value == 0 and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
        
    assert dut.result.value == 3, f"Expected 3, got {dut.result.value}"
    print("Test 2 Passed")

@cocotb.test()
async def test_coin_ways_three_types(dut):
    """Test case: 3 types, ratios 3,3, m=17"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # n=3, a1=3, a2=3, b0=10, b1=10, b2=10, m=17
    dut.n.value = 3
    dut.a_1.value = 3
    dut.a_2.value = 3
    dut.b_0.value = 10
    dut.b_1.value = 10
    dut.b_2.value = 10
    dut.m.value = 17
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while dut.done.value == 0 and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
        
    assert dut.result.value == 6, f"Expected 6, got {dut.result.value}"
    print("Test 3 Passed")
