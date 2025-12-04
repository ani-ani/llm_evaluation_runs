import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_break_scheduler(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset the module
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # T=8, N=3, breaks=[4,4,4], expected=[0,2,4]
        {"T": 8, "N": 3, "breaks": [4,4,4], "expected": [0,2,4]},
        # T=10, N=5, breaks=[7,5,1,2,3], expected=[3,3,9,0,0]
        {"T": 10, "N": 5, "breaks": [7,5,1,2,3], "expected": [3,3,9,0,0]}
    ]
    
    passed = 0
    for case in test_cases:
        # Load inputs
        dut.T.value = case["T"]
        dut.N.value = case["N"]
        for i in range(5):
            dut.breaks[i].value = case["breaks"][i] if i < case["N"] else 0
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (10 cycles)
        for _ in range(10):
            await RisingEdge(dut.clk)
        
        # Verify outputs
        correct = True
        for i in range(case["N"]):
            actual = dut.start_times[i].value.integer
            expected = case["expected"][i]
            if actual != expected:
                dut._log.error(f"Musician {i}: expected={expected}, got={actual}")
                correct = False
        
        if correct:
            passed += 1
        
        # Reset between tests
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
