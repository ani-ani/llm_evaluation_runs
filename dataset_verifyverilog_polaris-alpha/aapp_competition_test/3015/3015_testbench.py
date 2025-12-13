import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
import random

@cocotb.test()
async def test_hamster(dut):
    clock = cocotb.clock.Clock(dut.clk, 10, units="ns") # Create 100MHz clock
    cocotb.start_soon(clock.start()) # Start clock
    test_cases = [
        # Test 1: Simple path (scaled from sample 1)
        {
            'edges': [(0,1,1), (1,2,2), (2,3,1)],
            'start': 0,'bed': 3,'cycles': 8,'expected_time': 4,'inf': 0
        },
        # Test 2: Cycle detection (scaled from sample 2)
        {
            'edges': [(0,1,1), (1,2,1), (2,0,1), (3,4,1)],
            'start': 0,'bed': 3,'cycles': 8,'expected_time': 0,'inf': 1
        },
        # Test 3: Direct path (sample 3)
        {
            'edges': [(0,1,2)],'start': 0,'bed': 1,'cycles': 2,
            'expected_time': 2,'inf': 0
        }
    ]
    passed = 0
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    for tc in test_cases:
        # Pack graph edges (4 edges max for simplicity)
        dut.edge_count.value = len(tc['edges'])
        for i in range(16):
            if i < len(tc['edges']):
                a,b,w = tc['edges'][i]
                packed = (a << 14) | (b << 12) | w
            else:
                packed = 0
            dut.graph_data.value = packed
            await RisingEdge(dut.clk)
        # Set inputs
        dut.start_node.value = tc['start']
        dut.bed_node.value = tc['bed']
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait for completion
        await ClockCycles(dut.clk, tc['cycles'])
        while not dut.done.value:
            await RisingEdge(dut.clk)
        # Check result
        inf_match = (dut.infinity.value == tc['inf'])
        time_match = (dut.min_time.value == tc['expected_time']) if not tc['inf'] else True
        if inf_match and time_match:
            passed +=1
        else:
            dut._log.error("FAIL: Start=%d Bed=%d | Got: %s%d | Exp: %s%d" % (
                tc['start'], tc['bed'],
                'INF ' if dut.infinity.value else '', dut.min_time.value,
                'INF ' if tc['inf'] else '', tc['expected_time']))
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))