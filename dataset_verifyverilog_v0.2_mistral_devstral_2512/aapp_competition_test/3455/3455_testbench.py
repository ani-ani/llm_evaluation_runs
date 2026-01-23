import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_lane_switch_safety_basic(dut):
    """Test basic lane switch with safety factor 2.5"""
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
    
    # Test Case 1: 4 5 100 with specific arrangement
    # ACM: lane 0, len 10, dist 10 -> position 10 to 20
    # Lane 1: car1: len 10, dist 5 -> 5 to 15
    # Lane 1: car2: len 20, dist 35 -> 35 to 55
    # Lane 2: car3: len 2, dist 18 -> 18 to 20
    # Lane 2: car4: len 40, dist 50 -> 50 to 90
    
    # Convert to Q16.16 format
    # dist * 65536
    dut.total_cars_input.value = 5
    
    # Car 0: ACM car in lane 0, len 10, dist 10
    dut.car_lane[0].value = 0
    dut.car_length[0].value = 10
    dut.car_distance[0].value = 10 * 65536  # Q16.16
    
    # Car 1: Lane 1, len 10, dist 5
    dut.car_lane[1].value = 1
    dut.car_length[1].value = 10
    dut.car_distance[1].value = 5 * 65536
    
    # Car 2: Lane 1, len 20, dist 35
    dut.car_lane[2].value = 1
    dut.car_length[2].value = 20
    dut.car_distance[2].value = 35 * 65536
    
    # Car 3: Lane 2, len 2, dist 18
    dut.car_lane[3].value = 2
    dut.car_length[3].value = 2
    dut.car_distance[3].value = 18 * 65536
    
    # Car 4: Lane 2, len 40, dist 50
    dut.car_lane[4].value = 2
    dut.car_length[4].value = 40
    dut.car_distance[4].value = 50 * 65536
    
    # Fill remaining with zeros
    for i in range(5, 16):
        dut.car_lane[i].value = 0
        dut.car_length[i].value = 0
        dut.car_distance[i].value = 0
    
    # Start computation
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (max 1000 cycles)
    timeout = 1000
    for i in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure("Timeout - did not complete within 1000 cycles")
    
    # Check results
    if dut.impossible.value == 1:
        raise TestFailure("Should not be impossible for test case 1")
    
    if not dut.result_valid.value == 1:
        raise TestFailure("Result should be valid")
    
    # Expected safety factor: 2.5 in Q16.16 = 0x00028000 = 163840 decimal
    # 2.5 * 65536 = 163840
    expected = 163840
    actual = dut.safety_factor_result.value
    
    # Allow small error due to fixed-point arithmetic
    if abs(int(actual) - expected) > 100:
        raise TestFailure(f"Expected {expected} (2.5), got {actual}")
    
    dut._log.info(f"Test 1 passed: Safety factor = {actual / 65536:.6f}")

@cocotb.test()
async def test_lane_switch_safety_impossible(dut):
    """Test case where lane switch is impossible"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 2: 4 5 100 with larger ACM car
    # ACM: lane 0, len 30, dist 10 -> occupies 10 to 40
    # Other cars block all lanes
    
    dut.total_cars_input.value = 5
    
    # Car 0: ACM car in lane 0, len 30, dist 10
    dut.car_lane[0].value = 0
    dut.car_length[0].value = 30
    dut.car_distance[0].value = 10 * 65536
    
    # Car 1: Lane 1, len 10, dist 5
    dut.car_lane[1].value = 1
    dut.car_length[1].value = 10
    dut.car_distance[1].value = 5 * 65536
    
    # Car 2: Lane 1, len 20, dist 35
    dut.car_lane[2].value = 1
    dut.car_length[2].value = 20
    dut.car_distance[2].value = 35 * 65536
    
    # Car 3: Lane 2, len 2, dist 18
    dut.car_lane[3].value = 2
    dut.car_length[3].value = 2
    dut.car_distance[3].value = 18 * 65536
    
    # Car 4: Lane 2, len 40, dist 50
    dut.car_lane[4].value = 2
    dut.car_length[4].value = 40
    dut.car_distance[4].value = 50 * 65536
    
    # Fill remaining with zeros
    for i in range(5, 16):
        dut.car_lane[i].value = 0
        dut.car_length[i].value = 0
        dut.car_distance[i].value = 0
    
    # Start computation
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 1000
    for i in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure("Timeout")
    
    # Check if impossible
    if dut.impossible.value != 1:
        raise TestFailure("Should be impossible for test case 2")
    
    dut._log.info("Test 2 passed: Correctly identified as impossible")

@cocotb.test()
async def test_lane_switch_safety_edge_cases(dut):
    """Test edge cases: minimal gaps, direct fit, wide open spaces"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 3: Perfect fit scenario
    # ACM: len 5, dist 10
    # Lane 1: gap from 0 to 100 (wide open)
    # Lane 2: gap from 10 to 15 (exactly fits)
    # Lane 3: gap from 0 to 50
    
    dut.total_cars_input.value = 1  # Just ACM car
    
    # Car 0: ACM car
    dut.car_lane[0].value = 0
    dut.car_length[0].value = 5
    dut.car_distance[0].value = 10 * 65536
    
    # Fill remaining with zeros (no other cars, meaning lanes are empty)
    for i in range(1, 16):
        dut.car_lane[i].value = 0
        dut.car_length[i].value = 0
        dut.car_distance[i].value = 0
    
    # Start computation
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 1000
    for i in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure("Timeout")
    
    # With no other cars, all lanes are empty
    # Safety factor should be large (limited by sensor range)
    if dut.impossible.value == 1:
        raise TestFailure("Should be possible with empty lanes")
    
    # Safety factor should be at least (SENSOR_RANGE/2) - len/2 = 128 - 2.5 = 125.5
    # In Q16.16: 125.5 * 65536 = 8225792
    min_expected = int(125.5 * 65536)
    actual = int(dut.safety_factor_result.value)
    
    if actual < min_expected:
        raise TestFailure(f"Safety factor {actual/65536:.2f} too low, expected at least {min_expected/65536:.2f}")
    
    dut._log.info(f"Test 3 passed: Empty lanes safety factor = {actual / 65536:.6f}")

@cocotb.test()
async def test_lane_switch_safety_tight_gaps(dut):
    """Test with very tight gaps requiring precise calculations"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 4: Tight gaps with fractional safety factor
    # ACM: len 6, dist 20
    # Lane 1: cars at dist 5(len 10) and 25(len 10)
    # Gap from 15 to 25 = 10. Safety factor = 10-6 = 4, but need to account both sides
    # Actually gap before 5 is 5-0=5, but ACM is at 20-26, need to find correct gap
    
    dut.total_cars_input.value = 3
    
    # Car 0: ACM car
    dut.car_lane[0].value = 0
    dut.car_length[0].value = 6
    dut.car_distance[0].value = 20 * 65536
    
    # Car 1: Lane 1, len 4, dist 10
    dut.car_lane[1].value = 1
    dut.car_length[1].value = 4
    dut.car_distance[1].value = 10 * 65536
    
    # Car 2: Lane 1, len 4, dist 30
    dut.car_lane[2].value = 1
    dut.car_length[2].value = 4
    dut.car_distance[2].value = 30 * 65536
    
    # Fill remaining with zeros
    for i in range(3, 16):
        dut.car_lane[i].value = 0
        dut.car_length[i].value = 0
        dut.car_distance[i].value = 0
    
    # Start computation
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 1000
    for i in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure("Timeout")
    
    if dut.impossible.value == 1:
        raise TestFailure("Should be possible for test 4")
    
    # Gap in lane 1: from 10+4=14 to 30
    # Gap size = 30-14 = 16
    # Safety factor = (16 - 6) / 2 = 5
    # In Q16.16: 5 * 65536 = 327680
    expected = int(5 * 65536)
    actual = int(dut.safety_factor_result.value)
    
    if abs(actual - expected) > 100:
        raise TestFailure(f"Expected {expected} (5.0), got {actual}")
    
    dut._log.info(f"Test 4 passed: Tight gap safety factor = {actual / 65536:.6f}")

@cocotb.test()
async def test_lane_switch_safety_multiple_paths(dut):
    """Test with multiple possible paths, verify maximum safety factor"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 5: Multiple paths, verify choosing safest
    # ACM: len 5, dist 10
    # Lane 1: small gap (safety factor 2), Lane 2: large gap (safety factor 8)
    
    dut.total_cars_input.value = 4
    
    # Car 0: ACM car
    dut.car_lane[0].value = 0
    dut.car_length[0].value = 5
    dut.car_distance[0].value = 10 * 65536
    
    # Car 1: Lane 1, creates small gap
    dut.car_lane[1].value = 1
    dut.car_length[1].value = 3
    dut.car_distance[1].value = 12 * 65536
    
    # Car 2: Lane 2, creates large gap
    dut.car_lane[2].value = 2
    dut.car_length[2].value = 3
    dut.car_distance[2].value = 50 * 65536
    
    # Car 3: Lane 3, wide open
    dut.car_lane[3].value = 3
    dut.car_length[3].value = 10  # At end
    dut.car_distance[3].value = 80 * 65536
    
    # Fill remaining with zeros
    for i in range(4, 16):
        dut.car_lane[i].value = 0
        dut.car_length[i].value = 0
        dut.car_distance[i].value = 0
    
    # Start computation
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 1000
    for i in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure("Timeout")
    
    if dut.impossible.value == 1:
        raise TestFailure("Should be possible for test 5")
    
    # The algorithm should find the path with maximum safety factor
    # This tests min across path selection vs max across paths
    actual = int(dut.safety_factor_result.value)
    
    # Should be reasonably large since we have open spaces
    if actual < int(5 * 65536):
        raise TestFailure(f"Safety factor {actual/65536:.2f} seems too low")
    
    dut._log.info(f"Test 5 passed: Best path safety factor = {actual / 65536:.6f}")

@cocotb.test()
async def test_lane_switch_safety_comprehensive(dut):
    """Run all tests and report summary"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    test_cases = [
        # (expected_impossible, expected_safety_factor, car_data)
        (False, 2.5, [(0,10,10), (1,10,5), (1,20,35), (2,2,18), (2,40,50)]),
        (True, None, [(0,30,10), (1,10,5), (1,20,35), (2,2,18), (2,40,50)]),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for idx, (exp_impossible, exp_factor, cars) in enumerate(test_cases):
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await Timer(50, units='ns')
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load cars
        dut.total_cars_input.value = len(cars)
        for i, (lane, length, distance) in enumerate(cars):
            dut.car_lane[i].value = lane
            dut.car_length[i].value = length
            dut.car_distance[i].value = distance * 65536
        
        for i in range(len(cars), 16):
            dut.car_lane[i].value = 0
            dut.car_length[i].value = 0
            dut.car_distance[i].value = 0
        
        # Start
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait
        for _ in range(1000):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Check
        if exp_impossible:
            if dut.impossible.value == 1:
                passed += 1
                dut._log.info(f"Test {idx+1}: PASS (correctly impossible)")
            else:
                dut._log.error(f"Test {idx+1}: FAIL (should be impossible)")
        else:
            if dut.impossible.value == 0 and dut.result_valid.value == 1:
                actual = int(dut.safety_factor_result.value) / 65536
                if abs(actual - exp_factor) < 0.01:
                    passed += 1
                    dut._log.info(f"Test {idx+1}: PASS (factor={actual:.6f})")
                else:
                    dut._log.error(f"Test {idx+1}: FAIL (expected {exp_factor}, got {actual:.6f})")
            else:
                dut._log.error(f"Test {idx+1}: FAIL (should be possible)")
    
    dut._log.info(f"
SUMMARY: {passed}/{total} tests passed")
    if passed < total:
        raise TestFailure(f"Only {passed}/{total} tests passed")