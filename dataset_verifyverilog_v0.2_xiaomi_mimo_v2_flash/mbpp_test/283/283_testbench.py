import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_digit_validator(dut):
    # Create a 10ns period clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Initialize inputs
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.number.value = 0
    
    # Reset pulse
    await Timer(25, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: 1234 - Valid (1x1, 2x1, 3x1, 4x1)
    dut.number.value = 1234
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (max 40 cycles)
    timeout = 50
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 1: Done not asserted after 40 cycles")
    
    if dut.valid.value != 1:
        raise TestFailure(f"Test 1: Expected valid=1 for 1234, got {dut.valid.value}")
    print("Test 1 passed: 1234 -> Valid")
    
    # Wait for start to go low and cycle back to IDLE
    await RisingEdge(dut.clk)
    
    # Test 2: 51241 - Invalid (digit 1 appears 2 times, but d=1)
    dut.number.value = 51241
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 50
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 2: Done not asserted after 40 cycles")
    
    if dut.valid.value != 0:
        raise TestFailure(f"Test 2: Expected valid=0 for 51241, got {dut.valid.value}")
    print("Test 2 passed: 51241 -> Invalid")
    
    await RisingEdge(dut.clk)
    
    # Test 3: 321 - Valid (1x1, 2x1, 3x1)
    dut.number.value = 321
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 50
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 3: Done not asserted after 40 cycles")
    
    if dut.valid.value != 1:
        raise TestFailure(f"Test 3: Expected valid=1 for 321, got {dut.valid.value}")
    print("Test 3 passed: 321 -> Valid")
    
    await RisingEdge(dut.clk)
    
    # Test 4: 0 - Valid (digit 0 appears 1 time, 0 < 1 -> invalid... wait)
    # Actually 0 should be invalid because digit 0 appears 1 time, but count[0]=1 > 0
    # Let's use 100 instead - digit 0 appears 2 times, 2 > 0 -> invalid
    # Let's use 122333 - valid? digit 1:1<=1, digit 2:2<=2, digit 3:3<=3 -> valid
    dut.number.value = 122333
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 50
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 4: Done not asserted after 40 cycles")
    
    if dut.valid.value != 1:
        raise TestFailure(f"Test 4: Expected valid=1 for 122333, got {dut.valid.value}")
    print("Test 4 passed: 122333 -> Valid")
    
    await RisingEdge(dut.clk)
    
    # Test 5: 100 - Invalid (digit 0 appears 2 times, 2 > 0)
    dut.number.value = 100
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 50
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 5: Done not asserted after 40 cycles")
    
    if dut.valid.value != 0:
        raise TestFailure(f"Test 5: Expected valid=0 for 100, got {dut.valid.value}")
    print("Test 5 passed: 100 -> Invalid")
    
    print(f"
Summary: All 5 tests passed")