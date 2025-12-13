import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random
@cocotb.test()
async def test_city_decoration(dut):
    # Create 50MHz clock
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # Test 1: Impossible case (triangle with conflict)
        {"edges": [(1,2), (2,3), (1,3), (0,0), (0,0), (0,0)], "m_actual": 3, "expected": -1},
        # Test 2: Possible valid decoration 
        {"edges": [(1,2), (2,3), (3,4), (4,1), (0,0), (0,0)], "m_actual": 4, "expected": 4},
        # Test 3: Single road - valid cost 0
        {"edges": [(1,2), (0,0), (0,0), (0,0), (0,0), (0,0)], "m_actual": 1, "expected": 0}
    ]
    
    passed = 0
    for tc in test_cases:
        # Pack edges into 2-bit pairs per road
        edge_packed = [((a << 2) | b) for (a,b) in tc["edges"]]
        for i in range(6):
            dut.edges[i].value = edge_packed[i] if i < len(edge_packed) else 0
        dut.m_actual.value = tc["m_actual"]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        res = dut.min_cost.value.signed_integer
        if res == tc["expected"]:
            passed += 1
        else:
            dut._log.error(f"Failed: Expected {tc['expected']}, got {res}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)