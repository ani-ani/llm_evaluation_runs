import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def test_polygon_kernel(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # Test Case 1
        {
            "n": 5,
            "x": [200, 100, 0, -200, 0],
            "y": [0, 100, 200, 0, -200],
            "expected_area": 80000
        },
        # Test Case 2
        {
            "n": 5,
            "x": [20, 0, 0, -20, 0],
            "y": [0, -20, 0, 0, 20],
            "expected_area": 200
        },
        # Test Case 3
        {
            "n": 6,
            "x": [0, 500, 200, 500, 0, 300],
            "y": [0, 0, 100, 500, 500, 400],
            "expected_area": 0
        }
    ]
    
    passed = 0
    for case in test_cases:
        # Apply inputs
        dut.n.value = case["n"]
        for i in range(8):
            dut.x[i].value = case["x"][i] if i < case["n"] else 0
            dut.y[i].value = case["y"][i] if i < case["n"] else 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 10 cycles
        for _ in range(10):
            await RisingEdge(dut.clk)
        
        # Verify output
        if dut.done.value == 1 and dut.area.value == case["expected_area"]:
            passed += 1
        else:
            dut._log.error(f"Test failed: Expected {case['expected_area']}, got {dut.area.value}")
    
    # Report results
    total = len(test_cases)
    dut._log.info(f"{passed}/{total} test cases passed")
    assert passed == total, "Some test cases failed"