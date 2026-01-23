import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_sum_collatz(dut):
    """Test the sum_collatz module with scaled inputs."""
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.L.value = 0
    dut.R.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Helper to compute expected value (Python implementation)
    def f(x):
        iters = 0
        while x != 1:
            if x % 2 == 0:
                x = x // 2
            else:
                x = x + 1
            iters += 1
        return iters

    # Test Case 1: Small range 1 to 127 (Result 1083)
    # Since inputs are 16-bit, 127 is fine.
    dut.L.value = 1
    dut.R.value = 127
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for done
    timeout = 0
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
        timeout += 1
        if timeout > 5000:
            raise TimeoutError("Simulation timed out")

    # Calculate expected
    expected = 0
    for i in range(1, 128):
        expected += f(i)
    
    dut._log.info(f"Test 1: L=1, R=127. Expected: {expected}, Got: {int(dut.sum.value)}")
    assert int(dut.sum.value) == expected, f"Mismatch: {int(dut.sum.value)} != {expected}"

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    # Test Case 2: Single value 74 (Result 11)
    dut.L.value = 74
    dut.R.value = 74
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    timeout = 0
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
        timeout += 1
        if timeout > 5000:
            raise TimeoutError("Simulation timed out")

    expected = f(74)
    dut._log.info(f"Test 2: L=74, R=74. Expected: {expected}, Got: {int(dut.sum.value)}")
    assert int(dut.sum.value) == expected

    await RisingEdge(dut.clk)

    # Test Case 3: Edge case 1 to 1 (Result 0)
    dut.L.value = 1
    dut.R.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
        timeout += 1
        if timeout > 5000:
            raise TimeoutError("Simulation timed out")
            
    assert int(dut.sum.value) == 0
    
    # Test Case 4: Range 1 to 10
    dut.L.value = 1
    dut.R.value = 10
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
        timeout += 1
        if timeout > 5000:
            raise TimeoutError("Simulation timed out")
            
    expected = sum(f(i) for i in range(1, 11))
    assert int(dut.sum.value) == expected
