import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_cave_pathfinder(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to pack passage data
    def pack_passage(e, b, a, h):
        return (e << 48) | (b << 32) | (a << 16) | h
    
    # Test case 1: Sample Input 1 (expected "Oh no")
    passages = [pack_passage(1, 2, 1, 2), pack_passage(2, 3, 1, 2)]
    
    dut.unnars_attack.value = 1
    dut.unnars_health.value = 2
    dut.num_nodes.value = 3
    dut.num_passages.value = 2
    for i in range(16):
        dut.passages[i].value = passages[i] if i < len(passages) else 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max 100 cycles)
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.oh_no.value == 1, "Test 1 should output Oh no"
    
    # Test case 2: Sample Input 2 (expected health=1)
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.unnars_attack.value = 1
    dut.unnars_health.value = 3
    dut.num_nodes.value = 3
    dut.num_passages.value = 2
    for i in range(16):
        dut.passages[i].value = passages[i] if i < len(passages) else 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.oh_no.value == 0, "Test 2 should find a path"
    assert dut.max_health.value == 1, f"Test 2: Expected 1, got {dut.max_health.value.integer}"
    
    # Test case 3: Larger example (scaled)
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passages = [
        pack_passage(1,2,10,6), pack_passage(1,3,2,15),
        pack_passage(1,4,1,33), pack_passage(2,5,1,7),
        pack_passage(3,4,1000,5), pack_passage(4,2,5,9)
    ]
    
    dut.unnars_attack.value = 5
    dut.unnars_health.value = 20
    dut.num_nodes.value = 5
    dut.num_passages.value = 6
    for i in range(16):
        dut.passages[i].value = passages[i] if i < len(passages) else 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.oh_no.value == 0, "Test 3 should find a path"
    assert dut.max_health.value == 10, f"Test 3: Expected 10, got {dut.max_health.value.integer}"
    
    dut._log.info("3/3 tests passed")