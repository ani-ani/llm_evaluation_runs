import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
from random import sample

@cocotb.test()
async def test_pig_escape(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: Small tree (V=6 P=3 simplified)
    test_cases = [
        {
            "v": 6,
            "p": 3,
            "edges": [0,1,1,2,2,3,2,4,1,5],
            "pigs": [1,2,5],
            "wolves": [0,3,4],  # remaining nodes
            "expected": 0
        },
        {
            "v": 5,
            "p": 3,
            "edges": [0,1,1,2,2,3,3,4],
            "pigs": [1,3,4],    
            "wolves": [0,2],
            "expected": 1  # remove wolf at 2 for pig at 3
        }
    ]
    
    passed = 0
    for case in test_cases:
        # Format inputs
        dut.v.value = case["v"]
        dut.p.value = case["p"]
        
        # Pack edges to 32 bits (5 edges * 6 pairs = 30 bits)
        edges_packed = 0
        for i, val in enumerate(case["edges"]):
            edges_packed |= (val & 0x7) << (i*3)
        dut.edges_vec.value = edges_packed
        
        # Pack pigs
        pigs_packed = 0
        for i, p in enumerate(case["pigs"]):
            pigs_packed |= (p & 0x7) << (i*3)
        dut.pigs_vec.value = pigs_packed
        
        # Pack wolves
        wolves_packed = 0
        for i, w in enumerate(case["wolves"]):
            wolves_packed |= (w & 0x7) << (i*3)
        dut.wolves_vec.value = wolves_packed
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 24 cycles
        for _ in range(24):
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.done.value == 1 and dut.result.value == case["expected"]:
            passed += 1
        else:
            dut._log.error("Test failed: Expected %d, got %d" % 
                          (case["expected"], dut.result.value))
    
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))

    # Validate done signal drops
    await Timer(10, units="ns")
    assert dut.done.value == 0, "Done signal should drop after read"