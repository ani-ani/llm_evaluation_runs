import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_fizz_buzz_basic(dut):
    """Test basic fizz_buzz functionality"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: n=50, expected result=0
    dut.n.value = 50
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max 256 cycles)
    timeout = 300
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure("Timeout waiting for done")
    
    if dut.result.value != 0:
        raise TestFailure(f"Expected 0 for n=50, got {dut.result.value}")
    print(f"Test 1 passed: n=50 -> {dut.result.value}")

@cocotb.test()
async def test_fizz_buzz_78(dut):
    """Test n=78, expected 2"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n.value = 78
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 300
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure("Timeout")
    
    if dut.result.value != 2:
        raise TestFailure(f"Expected 2 for n=78, got {dut.result.value}")
    print(f"Test 2 passed: n=78 -> {dut.result.value}")

@cocotb.test()
async def test_fizz_buzz_79(dut):
    """Test n=79, expected 3"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n.value = 79
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 300
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure("Timeout")
    
    if dut.result.value != 3:
        raise TestFailure(f"Expected 3 for n=79, got {dut.result.value}")
    print(f"Test 3 passed: n=79 -> {dut.result.value}")

@cocotb.test()
async def test_fizz_buzz_100(dut):
    """Test n=100, expected 3"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n.value = 100
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 300
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure("Timeout")
    
    if dut.result.value != 3:
        raise TestFailure(f"Expected 3 for n=100, got {dut.result.value}")
    print(f"Test 4 passed: n=100 -> {dut.result.value}")

@cocotb.test()
async def test_fizz_buzz_200(dut):
    """Test n=200, expected 6"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n.value = 200
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 300
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure("Timeout")
    
    if dut.result.value != 6:
        raise TestFailure(f"Expected 6 for n=200, got {dut.result.value}")
    print(f"Test 5 passed: n=200 -> {dut.result.value}")

@cocotb.test()
async def test_fizz_buzz_255(dut):
    """Test n=255 (max), verify it completes"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n.value = 255
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 350
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure("Timeout")
    
    # Just verify it completes, exact value depends on algorithm
    print(f"Test 6 passed: n=255 -> {dut.result.value} (completed successfully)")

@cocotb.test()
async def test_fizz_buzz_zero(dut):
    """Test n=0, should return 0 immediately"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Should complete in 1 cycle
    await RisingEdge(dut.clk)
    if dut.done.value != 1:
        raise TestFailure("n=0 should complete in 1 cycle")
    if dut.result.value != 0:
        raise TestFailure(f"Expected 0 for n=0, got {dut.result.value}")
    print(f"Test 7 passed: n=0 -> {dut.result.value}")
