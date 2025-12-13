import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_min_path(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    test_cases = [
        # Test case 1 (3x3 grid, k=3)
        {"grid": [[1,2,3,0], [4,5,6,0], [7,8,9,0], [0,0,0,0]], "k": 3, "expected": [1,2,1]},
        # Test case 2 (standard test case)
        {"grid": [[5,9,3,0], [4,1,6,0], [7,8,2,0], [0,0,0,0]], "k": 1, "expected": [1]},
        # Test case 3 (4x4 with smaller k)
        {"grid": [[1,2,3,4], [5,6,7,8], [9,10,11,12], [13,14,15,16]], "k": 4, "expected": [1,2,1,2]},
        # Test case 4 (edge case: 2x2 implicit grid, k=10)
        {"grid": [[1,2,0,0], [3,4,0,0], [0,0,0,0], [0,0,0,0]], "k": 10, "expected": [1,2,1,2,1,2,1,2,1,2]},
        # Test case 5 (loop pattern check)
        {"grid": [[6,1,5,0], [3,8,9,0], [2,7,4,0], [0,0,0,0]], "k": 8, "expected": [1,5,1,5,1,5,1,5]}
    ]

    passed = 0
    for case in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Load grid
        for i in range(4):
            for j in range(4):
                dut.grid[i][j].value = case["grid"][i][j]

        # Set k and start
        dut.k.value = case["k"]
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Verify result
        expected = case["expected"]
        path = []
        value = int(dut.path.value)

        # Extract k elements
        for _ in range(case["k"]):
            path.append(value & 0xF)
            value = value >> 4
        
        # Check path (reverse order comparison)
        path.reverse()
        if path == expected:
            passed += 1
            dut._log.info(f"PASS: k={case['k']} got {path}")
        else:
            dut._log.error(f"FAIL: k={case['k']} expected {expected}, got {path}")
        
        await RisingEdge(dut.clk)

    dut._log.info(f"TEST SUMMARY: {passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)