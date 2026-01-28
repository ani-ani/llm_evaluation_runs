import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

# Planet name to index mapping
PLANET_MAP = {
    "Mercury": 0,
    "Venus": 1,
    "Earth": 2,
    "Mars": 3,
    "Jupiter": 4,
    "Saturn": 5,
    "Uranus": 6,
    "Neptune": 7
}

def str_to_ascii_list(s):
    """Convert string to list of 8 ASCII codes (padded with spaces)."""
    ascii_vals = [ord(c) for c in s]
    while len(ascii_vals) < 8:
        ascii_vals.append(32)  # Pad with space
    return ascii_vals[:8]

def calculate_expected(planet1, planet2):
    """Calculate the expected bitmask."""
    if planet1 not in PLANET_MAP or planet2 not in PLANET_MAP:
        return 0
    
    idx1 = PLANET_MAP[planet1]
    idx2 = PLANET_MAP[planet2]
    
    if idx1 == idx2:
        return 0
    
    # Determine range
    low = min(idx1, idx2)
    high = max(idx1, idx2)
    
    # Create bitmask for planets strictly between
    mask = 0
    for i in range(low + 1, high):
        mask |= (1 << i)
        
    return mask

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_planet_filter(dut):
    """Test the planet filter module."""
    
    # Test cases: (planet1, planet2, expected_result_description)
    test_cases = [
        ("Jupiter", "Neptune", "Saturn and Uranus"),
        ("Earth", "Mercury", "Venus"),
        ("Mercury", "Uranus", "Venus, Earth, Mars, Jupiter, Saturn"),
        ("Neptune", "Venus", "Earth, Mars, Jupiter, Saturn, Uranus"),
        ("Earth", "Earth", "None (same planet)"),
        ("Mars", "Earth", "None (same range inverted)"),
        ("Jupiter", "Makemake", "None (invalid planet)"),
        ("Mars", "Jupiter", "None (adjacent)"),
        ("Mercury", "Mars", "Venus, Earth")
    ]
    
    passed = 0
    total = len(test_cases)
    
    dut._log.info(f"Starting {total} tests...")
    
    for i, (p1, p2, description) in enumerate(test_cases):
        # Prepare inputs
        p1_vals = str_to_ascii_list(p1)
        p2_vals = str_to_ascii_list(p2)
        
        # Assign to DUT
        for j in range(8):
            dut.planet1_char0.value = p1_vals[0]
            dut.planet1_char1.value = p1_vals[1]
            dut.planet1_char2.value = p1_vals[2]
            dut.planet1_char3.value = p1_vals[3]
            dut.planet1_char4.value = p1_vals[4]
            dut.planet1_char5.value = p1_vals[5]
            dut.planet1_char6.value = p1_vals[6]
            dut.planet1_char7.value = p1_vals[7]
            
            dut.planet2_char0.value = p2_vals[0]
            dut.planet2_char1.value = p2_vals[1]
            dut.planet2_char2.value = p2_vals[2]
            dut.planet2_char3.value = p2_vals[3]
            dut.planet2_char4.value = p2_vals[4]
            dut.planet2_char5.value = p2_vals[5]
            dut.planet2_char6.value = p2_vals[6]
            dut.planet2_char7.value = p2_vals[7]
        
        # Wait for combinational propagation
        await Timer(10, units='ns')
        
        # Check output validity
        if not is_value_defined(dut.result.value):
            dut._log.error(f"Test {i} ({p1}, {p2}): Output is undefined (X/Z)")
            continue
        
        actual = int(dut.result.value)
        expected = calculate_expected(p1, p2)
        
        if actual == expected:
            passed += 1
            dut._log.info(f"Test {i} PASS: ({p1}, {p2}) -> 0x{actual:02X} [Expected: {description}]")
        else:
            dut._log.error(f"Test {i} FAIL: ({p1}, {p2}) -> 0x{actual:02X}, expected 0x{expected:02X} [Expected: {description}]")
    
    dut._log.info(f"\nResults: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"{total - passed} tests failed")
