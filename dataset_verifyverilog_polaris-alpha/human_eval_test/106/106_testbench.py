import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_factorial_sum(dut):
    # Define test cases (n, expected_array)
    test_cases = [
        (1, [1]),
        (3, [1, 2, 6]),
        (5, [1, 2, 6, 24, 15]),
        (7, [1, 2, 6, 24, 15, 720, 28])
    ]
    
    # Create clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    passed = 0
    total = len(test_cases)
    
    for n_val, expected in test_cases:
        # Reset
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        dut.start.value = 0
        await RisingEdge(dut.clk)
        
        # Apply test case
        dut.n.value = n_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while dut.done.value != 1:
            await RisingEdge(dut.clk)
        
        # Check results
        errors = []
        for i in range(n_val):
            actual = dut.result_array[i].value.integer
            exp = expected[i]
            if actual != exp:
                errors.append(f"Index {i}: got {actual}, expected {exp}")
        
        if not errors:
            dut._log.info(f"PASS: n={n_val} → {expected}")
            passed += 1
        else:
            dut._log.error(f"FAIL: n={n_val} {', '.join(errors)}")
        
        # Add spacing between tests
        await RisingEdge(dut.clk)
    
    # Summary
    status = f"{passed}/{total} tests passed"
    assert passed == total, status
    dut._log.info(status)