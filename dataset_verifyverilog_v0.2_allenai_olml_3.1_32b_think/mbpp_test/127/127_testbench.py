import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_multiply_int(dut):
    """Test the iterative multiplication module"""
    # Create a clock generator (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.x.value = 0
    dut.y.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: 10 * 20 = 200
    print("Running Test Case 1: 10 * 20")
    dut.x.value = 10
    dut.y.value = 20
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (max cycles: 20 + overhead)
    for _ in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "Done signal not asserted"
    assert dut.result.value == 200, f"Expected 200, got {dut.result.value}"
    print("Test Case 1 Passed")

    # Wait a few cycles before next test
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    # Test Case 2: 5 * 10 = 50
    print("Running Test Case 2: 5 * 10")
    dut.x.value = 5
    dut.y.value = 10
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    for _ in range(15):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    assert dut.done.value == 1, "Done signal not asserted"
    assert dut.result.value == 50, f"Expected 50, got {dut.result.value}"
    print("Test Case 2 Passed")

    # Wait a few cycles
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    # Test Case 3: 4 * 8 = 32
    print("Running Test Case 3: 4 * 8")
    dut.x.value = 4
    dut.y.value = 8
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    for _ in range(12):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break

    assert dut.done.value == 1, "Done signal not asserted"
    assert dut.result.value == 32, f"Expected 32, got {dut.result.value}"
    print("Test Case 3 Passed")

    # Additional Test: Negative case -10 * 5 = -50
    print("Running Additional Test: -10 * 5")
    dut.x.value = -10
    dut.y.value = 5
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break

    assert dut.done.value == 1, "Done signal not asserted"
    assert dut.result.value == -50, f"Expected -50, got {dut.result.value}"
    print("Additional Test Passed")

    print("All 4 tests passed successfully!")