import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_pillar(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # Input: n=5, b=[1341, 2412, 1200, 3112, 2391]
        {
            "n": 5,
            "b": [1341, 2412, 1200, 3112, 2391],
            "expected_damage": 3,
            "expected_idx": 1
        },
        # Input: n=5, b=[1004, 1003, 1002, 1001, 1000]
        {
            "n": 5,
            "b": [1004, 1003, 1002, 1001, 1000],
            "expected_damage": 5,
            "expected_idx": 0
        }
    ]
    
    passed = 0
    for tc in test_cases:
        # Load test case values
        dut.n.value = tc["n"]
        for i in range(8):
            if i < tc["n"]:
                dut.b[i].value = tc["b"][i]
            else:
                dut.b[i].value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 100 cycles)
        timeout = 100
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
        
        # Check results
        if timeout == 0:
            dut._log.error("Test timed out")
        elif dut.max_damage.value == tc["expected_damage"] and dut.pillar_idx.value == tc["expected_idx"]:
            passed += 1
        else:
            dut._log.error(f"Failed: Expected {tc['expected_damage']} damage at pillar {tc['expected_idx']}, Got {dut.max_damage.value} at {dut.pillar_idx.value}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
