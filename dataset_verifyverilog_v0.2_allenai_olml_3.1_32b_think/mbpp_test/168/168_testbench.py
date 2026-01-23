import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_frequency_counter(dut):
    # Create a clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.target.value = 0
    dut.list.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Helper function to run a test case
    async def run_test(list_val, target_val, expected_count):
        dut._log.info(f"Testing list={list_val}, target={target_val}")
        
        # Load array (simulating hardware loading mechanism)
        # In Verilog, we usually pass arrays via flattened bus or initialization.
        # Here we assume the testbench can write to the array signal.
        # Python list to integer conversion for flattened verilog array
        flat_list = 0
        for i, val in enumerate(list_val):
            flat_list |= (val & 0xFF) << (i * 8)
        dut.list.value = flat_list
        dut.target.value = target_val
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 20
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        if dut.done.value != 1:
            raise TestFailure(f"Done signal not asserted within timeout")
            
        if dut.count.value != expected_count:
            raise TestFailure(f"Count mismatch. Expected {expected_count}, got {int(dut.count.value)}")

    # Test Case 1: Item not present
    await run_test([1, 2, 3, 0, 0, 0, 0, 0], 4, 0)

    # Test Case 2: Multiple items (3 appears 3 times)
    await run_test([1, 2, 2, 3, 3, 3, 4, 0], 3, 3)

    # Test Case 3: Items at start and end (1 appears 2 times)
    await run_test([0, 1, 2, 3, 1, 2, 0, 0], 1, 2)
    
    dut._log.info("All tests passed!")