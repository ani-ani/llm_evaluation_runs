import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_airplane_construction(dut):
    """Test airplane construction critical path with step elimination"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Simple 2-step dependency
    # N=2, times=[15,20], dependencies: step0 none, step1 depends on step0
    # Original critical path: 15 + 20 = 35
    # Remove step0: time = 0 + 20 = 20
    # Remove step1: time = 15 + 0 = 15
    # Result should be 15
    
    dut.step_count.value = 2
    dut.step_times.value = [15, 20, 0, 0, 0, 0, 0, 0]
    dut.dependencies.value = [0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]  # bit0=1 for step1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (up to 200 cycles)
    for _ in range(250):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Done signal not asserted within 250 cycles")
    
    result = int(dut.min_time.value)
    print(f"Test 1 - Expected: 15, Got: {result}")
    assert result == 15, f"Test 1 failed: expected 15, got {result}"
    
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 2: 4-step example
    # N=4, times=[10,40,70,10]
    # Step0: no deps
    # Step1: depends on step0
    # Step2: depends on step0
    # Step3: depends on steps 1 and 2
    # Original critical path: 10 + max(40,70) + 10 = 90
    # Remove step0: time = max(40,70) + 10 = 80
    # Remove step1: time = 10 + 70 + 10 = 90
    # Remove step2: time = 10 + 40 + 10 = 60
    # Remove step3: time = 10 + max(40,70) = 80
    # Result should be 60
    
    dut.step_count.value = 4
    dut.step_times.value = [10, 40, 70, 10, 0, 0, 0, 0]
    dut.dependencies.value = [0x00, 0x01, 0x01, 0x06, 0x00, 0x00, 0x00, 0x00]  # step1=bit0, step2=bit0, step3=bits1&2
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(250):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Done signal not asserted within 250 cycles")
    
    result = int(dut.min_time.value)
    print(f"Test 2 - Expected: 60, Got: {result}")
    assert result == 60, f"Test 2 failed: expected 60, got {result}"
    
    # Test Case 3: Chain of 3
    # N=3, times=[5,5,5], dependencies: 0->1->2
    # Remove middle step (step1) gives 5+5=10
    # Remove step0 or step2 gives 5+5=10
    # Result should be 10
    
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.step_count.value = 3
    dut.step_times.value = [5, 5, 5, 0, 0, 0, 0, 0]
    dut.dependencies.value = [0x00, 0x01, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(250):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Done signal not asserted within 250 cycles")
    
    result = int(dut.min_time.value)
    print(f"Test 3 - Expected: 10, Got: {result}")
    assert result == 10, f"Test 3 failed: expected 10, got {result}"
    
    print("
All tests passed!")
