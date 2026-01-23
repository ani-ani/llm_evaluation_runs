import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure, TestSuccess

# Helper to convert list of values to simulation
async def load_dials(dut, values):
    """Load initial dial values into the DUT."""
    dut.load.value = 1
    for i, val in enumerate(values):
        dut.load_addr.value = i
        dut.load_data.value = val
        await RisingEdge(dut.clk)
    dut.load.value = 0

async def process_operation(dut, A, B):
    """Perform one operation: start, wait for done, return sum."""
    dut.start.value = 1
    dut.A.value = A
    dut.B.value = B
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done signal
    timeout = 20 # Safety counter
    while not dut.done.value and timeout > 0:
        await RisingEdge(dut.clk)
        timeout -= 1
    
    if timeout == 0:
        raise TestFailure("Timeout waiting for done signal")
        
    return int(dut.sum_out.value)

@cocotb.test()
async def test_dial_game_basic(dut):
    """Test basic range sum and increment."""
    # Clock generation
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.load.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Load initial values: [1, 2, 3, 4, 0, 0, 0, 0] (representing dials 1-8)
    # Sample 1: 1234... (others 0)
    init_vals = [1, 2, 3, 4, 0, 0, 0, 0]
    await load_dials(dut, init_vals)
    
    # Test Case 1: Range 1-4 (indices 0-3). Expected sum: 1+2+3+4 = 10
    sum1 = await process_operation(dut, 1, 4)
    print(f"Op 1 [1,4]: Sum = {sum1}")
    if sum1 != 10:
        raise TestFailure(f"Expected 10, got {sum1}")
    
    # After op 1, values become [2, 3, 4, 5, 0, 0, 0, 0]
    
    # Test Case 2: Range 1-4 again. Expected sum: 2+3+4+5 = 14
    sum2 = await process_operation(dut, 1, 4)
    print(f"Op 2 [1,4]: Sum = {sum2}")
    if sum2 != 14:
        raise TestFailure(f"Expected 14, got {sum2}")
    
    # After op 2, values become [3, 4, 5, 6, 0, 0, 0, 0]
    
    # Test Case 3: Range 1-4 again. Expected sum: 3+4+5+6 = 18
    sum3 = await process_operation(dut, 1, 4)
    print(f"Op 3 [1,4]: Sum = {sum3}")
    if sum3 != 18:
        raise TestFailure(f"Expected 18, got {sum3}")

@cocotb.test()
async def test_dial_game_wraparound(dut):
    """Test wraparound logic (9->0) and partial ranges."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.load.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Init: [9, 8, 7, 6, 5, 4, 3, 2]
    init_vals = [9, 8, 7, 6, 5, 4, 3, 2]
    await load_dials(dut, init_vals)
    
    # Op 1: Range 1-1 (Index 0). Value 9. Sum=9.
    # After: Index 0 becomes 0.
    sum1 = await process_operation(dut, 1, 1)
    print(f"Op 1 [1,1]: Sum = {sum1}")
    if sum1 != 9:
        raise TestFailure(f"Expected 9, got {sum1}")
        
    # Op 2: Range 1-3 (Indices 0,1,2). Values 0, 8, 7. Sum=0+8+7=15.
    # After: [1, 9, 8, 6, 5, 4, 3, 2]
    sum2 = await process_operation(dut, 1, 3)
    print(f"Op 2 [1,3]: Sum = {sum2}")
    if sum2 != 15:
        raise TestFailure(f"Expected 15, got {sum2}")
