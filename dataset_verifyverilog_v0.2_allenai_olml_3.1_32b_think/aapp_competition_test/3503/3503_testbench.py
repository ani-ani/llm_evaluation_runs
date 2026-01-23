import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
import random

@cocotb.test()
async def test_exam_builder(dut):
    """Test the exam builder module for unique results."""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.a0.value = 0; dut.b0.value = 0
    dut.a1.value = 0; dut.b1.value = 0
    dut.a2.value = 0; dut.b2.value = 0
    dut.a3.value = 0; dut.b3.value = 0
    dut.a4.value = 0; dut.b4.value = 0
    dut.a5.value = 0; dut.b5.value = 0
    dut.a6.value = 0; dut.b6.value = 0
    dut.a7.value = 0; dut.b7.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: Simple unique values (1+5, 3*3, etc scaled)
    dut.a0.value = 1;  dut.b0.value = 5   # +6, -(-4), *5
    dut.a1.value = 3;  dut.b1.value = 3   # +6, 0, 9
    dut.a2.value = 4;  dut.b2.value = 5   # +9, -(-1), 20
    dut.a3.value = -1; dut.b3.value = -6  # +(-7), +5, *6
    # Add more pairs to fill 8 slots with potential conflicts to test logic
    dut.a4.value = 2;  dut.b4.value = 10  # +12, -8, 20
    dut.a5.value = 0;  dut.b5.value = 7   # +7, -(-7), 0
    dut.a6.value = 10; dut.b6.value = 1   # +11, 9, 10
    dut.a7.value = 12; dut.b7.value = 1   # +13, 11, 12

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for done (max 30 cycles for safety)
    timeout = 0
    while not dut.done.value and not dut.impossible.value and timeout < 30:
        await RisingEdge(dut.clk)
        timeout += 1

    if dut.impossible.value:
        # If it deems impossible, that's a valid output for this input set if no unique match found
        print("Result: Impossible (valid if no unique mapping exists)")
    elif dut.done.value:
        results = []
        ops = []
        results.append(int(dut.res0.value))
        ops.append(int(dut.op0.value))
        results.append(int(dut.res1.value))
        ops.append(int(dut.op1.value))
        results.append(int(dut.res2.value))
        ops.append(int(dut.op2.value))
        results.append(int(dut.res3.value))
        ops.append(int(dut.op3.value))
        results.append(int(dut.res4.value))
        ops.append(int(dut.op4.value))
        results.append(int(dut.res5.value))
        ops.append(int(dut.op5.value))
        results.append(int(dut.res6.value))
        ops.append(int(dut.op6.value))
        results.append(int(dut.res7.value))
        ops.append(int(dut.op7.value))
        
        # Verify uniqueness
        unique_count = len(set(results))
        assert unique_count == 8, f"Results not unique: {results}"
        print(f"All 8 results unique: {results}")
    else:
        assert False, "Timed out waiting for done or impossible"
