import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_sheldon_counter(dut):
    """Test the sheldon_counter module."""
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.range_start.value = 0
    dut.range_end.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: 1 to 10 (Expect 10)
    # In Python: bin(1)->1, 2->10, 3->11, 4->100, 5->101, 6->110, 7->111, 8->1000, 9->1001, 10->1010
    # All are Sheldon numbers in this range according to sample.
    dut.range_start.value = 1
    dut.range_end.value = 10
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    count_val = int(dut.count.value)
    print(f"Test 1 (1-10): Expected 10, Got {count_val}")
    assert count_val == 10, f"Expected 10, got {count_val}"
    await RisingEdge(dut.clk)

    # Test Case 2: 70 to 75 (Expect 1)
    # 73 is the only one (1001001)
    dut.range_start.value = 70
    dut.range_end.value = 75
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
        # Timeout guard for simulation (limit cycles if needed, here assume fast enough for test or user handles wait)
        # For this test, we assume the module completes within reasonable time (e.g. 1000 cycles for small range logic)
        # In a real scenario, we might add a cycle counter to break, but here we rely on `done`.
    
    count_val = int(dut.count.value)
    print(f"Test 2 (70-75): Expected 1, Got {count_val}")
    assert count_val == 1, f"Expected 1, got {count_val}"
    
    print("All tests passed!")