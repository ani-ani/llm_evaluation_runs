import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_graph_path(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    test_cases = [
        # Test 1: N=3 towns (01), M=3 roads. Paths: 0->1 direct (2 edge pairs)
        {"N": 2, "M": 3, "edges": 0x0001001202100000,
         "inf": False, "count": 2},
        
        # Test 2: N=4 towns (3), M=4 roads, Cycle 2->3->2 (path 0->2->1)
        {"N": 3, "M": 4, "edges": 0x0012101111101001,
         "inf": True, "count": 0},
        
        # Test 3: N=2 towns (1), M=1 road, Single direct path 0->1
        {"N": 1, "M": 1, "edges": 0x0000000000000001,
         "inf": False, "count": 1}
    ]
    passed = 0
    
    for i, tc in enumerate(test_cases):
        # Apply test case inputs
        dut.N.value = tc["N"]
        dut.M.value = tc["M"]
        dut.edges.value = tc["edges"]
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done is high or timeout
        timeout = 20
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
        
        if timeout == 0:
            dut._log.error(f"Test {i} timed out")
            continue
        
        # Check results
        if tc["inf"]:
            if dut.result.value[31] != 1:
                dut._log.error(f"Test {i} FAIL: Expected inf, got count=%d", dut.result.value)
            else:
                passed += 1
        else:
            if dut.result.value[31] == 1:
                dut._log.error(f"Test {i} FAIL: Expected count={tc['count']}, got inf")
            elif dut.result.value[30:0].integer != tc["count"]:
                dut._log.error(f"Test {i} FAIL: Got count=%d, expected {tc['count']}", dut.result.value[30:0].integer)
            else:
                passed += 1
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)