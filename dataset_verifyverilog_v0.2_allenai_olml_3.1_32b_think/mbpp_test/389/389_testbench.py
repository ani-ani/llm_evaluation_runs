import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_lucas_basic(dut):
    """Test basic Lucas number calculations"""
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
    
    # Test case 1: n=9, expected L(9)=76
    dut.n.value = 9
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max 17 cycles for n=15)
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Done signal not asserted after 20 cycles")
    
    if dut.result.value != 76:
        raise TestFailure(f"Expected 76, got {int(dut.result.value)}")
    print(f"Test 1 passed: L(9) = {int(dut.result.value)}")
    
    # Wait a bit before next test
    await Timer(20, units='ns')

@cocotb.test()
async def test_lucas_case_4(dut):
    """Test L(4) = 7"""
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(10, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2: n=4, expected L(4)=7
    dut.n.value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    for _ in range(15):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Done signal not asserted")
    
    if dut.result.value != 7:
        raise TestFailure(f"Expected 7, got {int(dut.result.value)}")
    print(f"Test 2 passed: L(4) = {int(dut.result.value)}")

@cocotb.test()
async def test_lucas_case_3(dut):
    """Test L(3) = 4"""
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(10, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 3: n=3, expected L(3)=4
    dut.n.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    for _ in range(15):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Done signal not asserted")
    
    if dut.result.value != 4:
        raise TestFailure(f"Expected 4, got {int(dut.result.value)}")
    print(f"Test 3 passed: L(3) = {int(dut.result.value)}")

@cocotb.test()
async def test_lucas_edge_cases(dut):
    """Test edge cases: n=0, n=1, n=15"""
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(10, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test n=0: L(0) = 2
    dut.n.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk)
    if dut.done.value != 1:
        raise TestFailure("Done not asserted for n=0")
    if dut.result.value != 2:
        raise TestFailure(f"L(0) expected 2, got {int(dut.result.value)}")
    print(f"Edge test 1 passed: L(0) = {int(dut.result.value)}")
    
    # Wait
    await Timer(10, units='ns')
    await RisingEdge(dut.clk)
    
    # Test n=1: L(1) = 1
    dut.n.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk)
    if dut.done.value != 1:
        raise TestFailure("Done not asserted for n=1")
    if dut.result.value != 1:
        raise TestFailure(f"L(1) expected 1, got {int(dut.result.value)}")
    print(f"Edge test 2 passed: L(1) = {int(dut.result.value)}")
    
    # Wait
    await Timer(10, units='ns')
    await RisingEdge(dut.clk)
    
    # Test n=15: L(15) = 1364 (max case)
    dut.n.value = 15
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (should take ~17 cycles)
    for _ in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Done not asserted for n=15")
    if dut.result.value != 1364:
        raise TestFailure(f"L(15) expected 1364, got {int(dut.result.value)}")
    print(f"Edge test 3 passed: L(15) = {int(dut.result.value)}")

@cocotb.test()
async def test_lucas_all_cases(dut):
    """Run multiple test cases in sequence and report summary"""
    # Setup
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        (0, 2),
        (1, 1),
        (3, 4),
        (4, 7),
        (9, 76),
        (10, 123),  # Additional verification
        (12, 322),  # Additional verification
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, expected in test_cases:
        dut.n.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        cycles = 0
        while dut.done.value == 0 and cycles < 20:
            await RisingEdge(dut.clk)
            cycles += 1
        
        result = int(dut.result.value)
        if result == expected:
            passed += 1
            print(f"  ✓ n={n}: L({n})={result}")
        else:
            print(f"  ✗ n={n}: expected {expected}, got {result}")
        
        # Small delay between tests
        await Timer(10, units='ns')
        await RisingEdge(dut.clk)
    
    print(f"
Test Summary: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
