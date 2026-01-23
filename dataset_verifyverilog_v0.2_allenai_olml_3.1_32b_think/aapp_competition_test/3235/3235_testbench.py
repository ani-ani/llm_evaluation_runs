import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

async def load_iou(dut, a, b, c):
    dut.a_in.value = a
    dut.b_in.value = b
    dut.c_in.value = c
    dut.load_iou.value = 1
    await RisingEdge(dut.clk)
    dut.load_iou.value = 0
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_expense_settler(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.load_iou.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: Sample Input 2 (2 friends, simple cycle)
    # 0 1 20, 1 0 5 -> Result: 0 1 15
    dut.n.value = 2
    dut.m.value = 2
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Load IOUs
    await load_iou(dut, 0, 1, 20)
    await load_iou(dut, 1, 0, 5)
    
    # Wait for settlement to complete
    # The module should process and then output
    results = []
    timeout = 0
    
    while True:
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
        if dut.out_valid.value == 1:
            results.append((int(dut.out_a.value), int(dut.out_b.value), int(dut.out_c.value)))
        timeout += 1
        if timeout > 2000:
            raise TestFailure("Timeout waiting for done")
    
    # Check outputs
    # We expect 1 IOU: 0 1 15
    if len(results) != 1:
        raise TestFailure(f"Expected 1 IOU, got {len(results)}")
    
    res = results[0]
    if res[0] != 0 or res[1] != 1 or res[2] != 15:
        raise TestFailure(f"Expected 0 1 15, got {res[0]} {res[1]} {res[2]}")
    
    print("Test Case 1 Passed: 2 nodes cycle cancelled correctly")

    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 2: No Cycle (0 1 5)
    dut.n.value = 2
    dut.m.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await load_iou(dut, 0, 1, 5)
    
    results = []
    timeout = 0
    while True:
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
        if dut.out_valid.value == 1:
            results.append((int(dut.out_a.value), int(dut.out_b.value), int(dut.out_c.value)))
        timeout += 1
        if timeout > 2000:
            raise TestFailure("Timeout waiting for done")
            
    if len(results) != 1:
        raise TestFailure(f"Expected 1 IOU, got {len(results)}")
    res = results[0]
    if res[0] != 0 or res[1] != 1 or res[2] != 5:
        raise TestFailure(f"Expected 0 1 5, got {res[0]} {res[1]} {res[2]}")
    
    print("Test Case 2 Passed: No cycle preserved")

    # Test Case 3: Cancel to zero
    dut.n.value = 2
    dut.m.value = 2
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await load_iou(dut, 0, 1, 10)
    await load_iou(dut, 1, 0, 10)
    
    results = []
    timeout = 0
    while True:
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
        if dut.out_valid.value == 1:
            results.append((int(dut.out_a.value), int(dut.out_b.value), int(dut.out_c.value)))
        timeout += 1
        if timeout > 2000:
            raise TestFailure("Timeout waiting for done")
            
    if len(results) != 0:
        raise TestFailure(f"Expected 0 IOUs, got {len(results)}")
    
    print("Test Case 3 Passed: Complete cancellation")
