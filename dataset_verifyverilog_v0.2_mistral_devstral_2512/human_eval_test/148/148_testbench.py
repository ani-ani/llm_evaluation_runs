import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Planet ASCII encodings (8 bytes each)
PLANET_ENCODING = {
    "Mercury": 0x4d65726375727920,
    "Venus":   0x56656e7573202020,
    "Earth":   0x4561727468202020,
    "Mars":    0x4d61727320202020,
    "Jupiter": 0x4a75706974657220,
    "Saturn":  0x53617475726e2020,
    "Uranus":  0x5572616e75732020,
    "Neptune": 0x4e657074756e6520
}

PLANET_TO_INDEX = {
    "Mercury": 0,
    "Venus": 1,
    "Earth": 2,
    "Mars": 3,
    "Jupiter": 4,
    "Saturn": 5,
    "Uranus": 6,
    "Neptune": 7
}

def compute_expected(planet1, planet2):
    """Compute expected result for Python reference"""
    planets = ["Mercury", "Venus", "Earth", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune"]
    
    # Check validity
    if planet1 not in planets or planet2 not in planets:
        return 0, 0, True  # result_valid, result_count, invalid
    
    idx1 = PLANET_TO_INDEX[planet1]
    idx2 = PLANET_TO_INDEX[planet2]
    
    if idx1 == idx2:
        return 0, 0, False
    
    min_idx = min(idx1, idx2)
    max_idx = max(idx1, idx2)
    
    # Build result mask
    result_valid = 0
    result_count = 0
    for i in range(8):
        if min_idx < i < max_idx:
            result_valid |= (1 << i)
            result_count += 1
    
    return result_valid, result_count, False

@cocotb.test()
async def test_planet_orbits_basic(dut):
    """Test basic valid cases"""
    test_cases = [
        ("Jupiter", "Neptune", 0x60, 2),  # Saturn(5), Uranus(6)
        ("Earth", "Mercury", 0x02, 1),    # Venus(1)
        ("Mercury", "Uranus", 0x3E, 5),   # Venus(1) through Saturn(5)
        ("Neptune", "Venus", 0x3C, 4),    # Earth(2) through Uranus(6)
    ]
    
    for p1, p2, expected_valid, expected_count in test_cases:
        dut.planet1.value = PLANET_ENCODING[p1]
        dut.planet2.value = PLANET_ENCODING[p2]
        
        await Timer(10, units='ns')
        
        result_valid = int(dut.result_valid.value)
        result_count = int(dut.result_count.value)
        invalid = int(dut.invalid.value)
        
        if invalid != 0:
            raise TestFailure(f"Test {p1},{p2}: Expected invalid=0, got 1")
        if result_valid != expected_valid:
            raise TestFailure(f"Test {p1},{p2}: Expected valid=0x{expected_valid:x}, got 0x{result_valid:x}")
        if result_count != expected_count:
            raise TestFailure(f"Test {p1},{p2}: Expected count={expected_count}, got {result_count}")
        
        dut._log.info(f"PASS: {p1},{p2} -> valid=0x{result_valid:x}, count={result_count}")

@cocotb.test()
async def test_planet_orbits_edge_cases(dut):
    """Test edge cases: same planet, adjacent planets, invalid inputs"""
    # Same planet
    dut.planet1.value = PLANET_ENCODING["Earth"]
    dut.planet2.value = PLANET_ENCODING["Earth"]
    await Timer(10, units='ns')
    
    if int(dut.result_valid.value) != 0 or int(dut.result_count.value) != 0:
        raise TestFailure(f"Same planet test failed")
    dut._log.info("PASS: Earth,Earth -> empty")
    
    # Adjacent planets
    dut.planet1.value = PLANET_ENCODING["Mars"]
    dut.planet2.value = PLANET_ENCODING["Earth"]
    await Timer(10, units='ns')
    
    if int(dut.result_valid.value) != 0 or int(dut.result_count.value) != 0:
        raise TestFailure(f"Adjacent planets test failed")
    dut._log.info("PASS: Mars,Earth -> empty")
    
    # Invalid planet name
    dut.planet1.value = 0x4e6f7441506c616e  # "NotAPlanet"
    dut.planet2.value = PLANET_ENCODING["Venus"]
    await Timer(10, units='ns')
    
    if int(dut.invalid.value) != 1:
        raise TestFailure(f"Invalid planet test failed: expected invalid=1")
    dut._log.info("PASS: Invalid planet detected")

@cocotb.test()
async def test_planet_orbits_reverse_order(dut):
    """Test that order doesn't matter (orbit proximity)"""
    # Jupiter to Neptune (forward)
    dut.planet1.value = PLANET_ENCODING["Jupiter"]
    dut.planet2.value = PLANET_ENCODING["Neptune"]
    await Timer(10, units='ns')
    forward_valid = int(dut.result_valid.value)
    forward_count = int(dut.result_count.value)
    
    # Neptune to Jupiter (reverse)
    dut.planet1.value = PLANET_ENCODING["Neptune"]
    dut.planet2.value = PLANET_ENCODING["Jupiter"]
    await Timer(10, units='ns')
    reverse_valid = int(dut.result_valid.value)
    reverse_count = int(dut.result_count.value)
    
    if forward_valid != reverse_valid or forward_count != reverse_count:
        raise TestFailure(f"Order mismatch: forward 0x{forward_valid:x}, reverse 0x{reverse_valid:x}")
    dut._log.info(f"PASS: Order independence verified (both 0x{forward_valid:x})")

@cocotb.test()
async def test_all_planets(dut):
    """Test all valid planets as inputs"""
    planet_names = list(PLANET_ENCODING.keys())
    
    # Count total tests
    tests_passed = 0
    total_tests = 0
    
    for p1 in planet_names:
        for p2 in planet_names:
            total_tests += 1
            
            dut.planet1.value = PLANET_ENCODING[p1]
            dut.planet2.value = PLANET_ENCODING[p2]
            await Timer(10, units='ns')
            
            expected_valid, expected_count, expected_invalid = compute_expected(p1, p2)
            
            result_valid = int(dut.result_valid.value)
            result_count = int(dut.result_count.value)
            result_invalid = int(dut.invalid.value)
            
            if (result_valid == expected_valid and 
                result_count == expected_count and 
                result_invalid == expected_invalid):
                tests_passed += 1
            else:
                raise TestFailure(f"Failed: {p1},{p2} - Expected v={expected_valid},c={expected_count},i={expected_invalid}; Got v={result_valid},c={result_count},i={result_invalid}")
    
    dut._log.info(f"Summary: {tests_passed}/{total_tests} tests passed")
    if tests_passed != total_tests:
        raise TestFailure(f"Only {tests_passed} of {total_tests} passed")