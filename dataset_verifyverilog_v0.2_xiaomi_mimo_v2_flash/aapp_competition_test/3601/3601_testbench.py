import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import math

# Helper to convert float to Q16.16
def float_to_q16_16(val):
    return int(val * 65536) & 0xFFFFFFFF

# Helper to convert Q16.16 to float
def q16_16_to_float(val):
    if val & 0x80000000:  # Negative (sign extend)
        return -((~val + 1) / 65536.0)
    return val / 65536.0

@cocotb.test()
async def test_delivery_time_basic(dut):
    """Test basic case: Misha vertical, Nadia vertical, offset by 4 units"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Misha: (0,0) -> (0,10)
    # Nadia: (4,10) -> (4,0)
    # Expected: 4.0 (handoff at (0,5) and (4,5) takes 2.5 + sqrt(16)=4, but optimal is 4.0)
    
    dut.misha_points[0].value = float_to_q16_16(0.0)  # x0
    dut.misha_points[1].value = float_to_q16_16(0.0)  # y0
    dut.misha_points[2].value = float_to_q16_16(0.0)  # x1
    dut.misha_points[3].value = float_to_q16_16(10.0) # y1
    
    dut.nadia_points[0].value = float_to_q16_16(4.0)  # x0
    dut.nadia_points[1].value = float_to_q16_16(10.0) # y0
    dut.nadia_points[2].value = float_to_q16_16(4.0)  # x1
    dut.nadia_points[3].value = float_to_q16_16(0.0)  # y1
    
    dut.misha_count.value = 2
    dut.nadia_count.value = 2
    
    # Start computation
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (max 200 cycles)
    for _ in range(250):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    else:
        raise TestFailure("Timeout waiting for done")
    
    if dut.impossible.value:
        raise TestFailure("Result marked as impossible")
    
    result_time = q16_16_to_float(dut.result.value)
    expected = 4.0
    
    if abs(result_time - expected) > 0.01:
        raise TestFailure(f"Expected {expected}, got {result_time}")
    
    dut._log.info(f"Test 1 passed: {result_time}")

@cocotb.test()
async def test_delivery_time_diagonal(dut):
    """Test diagonal movement case"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Misha: (0,0) -> (1,1) -> (2,0) (V shape)
    # Nadia: (2,0) -> (3,0) -> (3,10)
    # Expected: 5.0
    
    dut.misha_points[0].value = float_to_q16_16(0.0)
    dut.misha_points[1].value = float_to_q16_16(0.0)
    dut.misha_points[2].value = float_to_q16_16(1.0)
    dut.misha_points[3].value = float_to_q16_16(1.0)
    dut.misha_points[4].value = float_to_q16_16(2.0)
    dut.misha_points[5].value = float_to_q16_16(0.0)
    
    dut.nadia_points[0].value = float_to_q16_16(2.0)
    dut.nadia_points[1].value = float_to_q16_16(0.0)
    dut.nadia_points[2].value = float_to_q16_16(3.0)
    dut.nadia_points[3].value = float_to_q16_16(0.0)
    dut.nadia_points[4].value = float_to_q16_16(3.0)
    dut.nadia_points[5].value = float_to_q16_16(10.0)
    
    dut.misha_count.value = 3
    dut.nadia_count.value = 3
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(250):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    else:
        raise TestFailure("Timeout")
    
    if dut.impossible.value:
        raise TestFailure("Impossible")
    
    result_time = q16_16_to_float(dut.result.value)
    expected = 5.0
    
    if abs(result_time - expected) > 0.1:  # Looser tolerance for complex case
        raise TestFailure(f"Expected {expected}, got {result_time}")
    
    dut._log.info(f"Test 2 passed: {result_time}")

@cocotb.test()
async def test_delivery_time_parallel(dut):
    """Test case where Misha and Nadia move in same direction"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Misha: (0,0) -> (10,0)
    # Nadia: (0,1) -> (10,1)
    # Minimal distance is 1 unit vertical. Handoff at start: Misha 0, Nadia 0, messenger 1 -> total 1.0
    
    dut.misha_points[0].value = float_to_q16_16(0.0)
    dut.misha_points[1].value = float_to_q16_16(0.0)
    dut.misha_points[2].value = float_to_q16_16(10.0)
    dut.misha_points[3].value = float_to_q16_16(0.0)
    
    dut.nadia_points[0].value = float_to_q16_16(0.0)
    dut.nadia_points[1].value = float_to_q16_16(1.0)
    dut.nadia_points[2].value = float_to_q16_16(10.0)
    dut.nadia_points[3].value = float_to_q16_16(1.0)
    
    dut.misha_count.value = 2
    dut.nadia_count.value = 2
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(250):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    else:
        raise TestFailure("Timeout")
    
    if dut.impossible.value:
        raise TestFailure("Impossible")
    
    result_time = q16_16_to_float(dut.result.value)
    expected = 1.0
    
    if abs(result_time - expected) > 0.01:
        raise TestFailure(f"Expected {expected}, got {result_time}")
    
    dut._log.info(f"Test 3 passed: {result_time}")

@cocotb.test()
async def test_delivery_time_staggered(dut):
    """Test staggered start times (handoff later in path)"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Misha: (0,0) -> (8,0) (travels 8 units)
    # Nadia: (4,6) -> (4,0) (travels 6 units down)
    # Optimal handoff somewhere mid-path
    
    dut.misha_points[0].value = float_to_q16_16(0.0)
    dut.misha_points[1].value = float_to_q16_16(0.0)
    dut.misha_points[2].value = float_to_q16_16(8.0)
    dut.misha_points[3].value = float_to_q16_16(0.0)
    
    dut.nadia_points[0].value = float_to_q16_16(4.0)
    dut.nadia_points[1].value = float_to_q16_16(6.0)
    dut.nadia_points[2].value = float_to_q16_16(4.0)
    dut.nadia_points[3].value = float_to_q16_16(0.0)
    
    dut.misha_count.value = 2
    dut.nadia_count.value = 2
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(250):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    else:
        raise TestFailure("Timeout")
    
    if dut.impossible.value:
        raise TestFailure("Impossible")
    
    result_time = q16_16_to_float(dut.result.value)
    expected = 6.0  # Approximate
    
    # Allow wider tolerance due to grid search approximation
    if abs(result_time - expected) > 0.5:
        raise TestFailure(f"Expected ~{expected}, got {result_time}")
    
    dut._log.info(f"Test 4 passed: {result_time}")

@cocotb.test()
async def test_delivery_time_impossible(dut):
    """Test case where delivery is impossible"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Misha: (0,0) -> (1,0) (very short)
    # Nadia: (100,100) -> (200,100) (very far, fast moving away)
    # Messenger can't catch up in time
    
    dut.misha_points[0].value = float_to_q16_16(0.0)
    dut.misha_points[1].value = float_to_q16_16(0.0)
    dut.misha_points[2].value = float_to_q16_16(1.0)
    dut.misha_points[3].value = float_to_q16_16(0.0)
    
    dut.nadia_points[0].value = float_to_q16_16(100.0)
    dut.nadia_points[1].value = float_to_q16_16(100.0)
    dut.nadia_points[2].value = float_to_q16_16(200.0)
    dut.nadia_points[3].value = float_to_q16_16(100.0)
    
    dut.misha_count.value = 2
    dut.nadia_count.value = 2
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(250):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    else:
        raise TestFailure("Timeout")
    
    if not dut.impossible.value:
        raise TestFailure("Should be impossible")
    
    dut._log.info("Test 5 passed: correctly identified impossible case")

@cocotb.test()
async def test_multiple_tests(dut):
    """Run all test cases sequentially"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    test_cases = [
        # Case 1: 2x2 vertical offset
        ([0.0,0.0, 0.0,10.0], [4.0,10.0, 4.0,0.0], 2, 2, 4.0),
        # Case 2: 3x3 diagonal  
        ([0.0,0.0, 1.0,1.0, 2.0,0.0], [2.0,0.0, 3.0,0.0, 3.0,10.0], 3, 3, 5.0),
        # Case 3: Parallel movement
        ([0.0,0.0, 10.0,0.0], [0.0,1.0, 10.0,1.0], 2, 2, 1.0),
    ]
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    total = len(test_cases)
    
    for i, (m_pts, n_pts, m_cnt, n_cnt, expected) in enumerate(test_cases):
        # Load points
        for j, pt in enumerate(m_pts):
            dut.misha_points[j].value = float_to_q16_16(pt)
        for j, pt in enumerate(n_pts):
            dut.nadia_points[j].value = float_to_q16_16(pt)
        
        dut.misha_count.value = m_cnt
        dut.nadia_count.value = n_cnt
        
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        for _ in range(250):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        
        if not dut.impossible.value:
            result = q16_16_to_float(dut.result.value)
            if abs(result - expected) <= 0.1:
                passed += 1
                dut._log.info(f"Case {i+1}: PASS (got {result}, expected {expected})")
            else:
                dut._log.error(f"Case {i+1}: FAIL (got {result}, expected {expected})")
        else:
            dut._log.error(f"Case {i+1}: FAIL (impossible)")
    
    dut._log.info(f"Summary: {passed}/{total} tests passed")
    if passed < total:
        raise TestFailure(f"Only {passed}/{total} passed")
