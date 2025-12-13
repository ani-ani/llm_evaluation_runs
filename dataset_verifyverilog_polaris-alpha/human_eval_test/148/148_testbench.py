import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_planets(dut):
    # Planet encodings
    planets = {"Mercury": 0, "Venus": 1, "Earth": 2, "Mars": 3,
              "Jupiter": 4, "Saturn": 5, "Uranus": 6, "Neptune": 7}
    
    test_cases = [
        # Valid cases
        ("Jupiter", "Neptune", ("Saturn", "Uranus"), 2),
        ("Earth", "Mercury", ("Venus",), 1),
        ("Mercury", "Uranus", ("Venus", "Earth", "Mars", "Jupiter", "Saturn"), 5),
        ("Neptune", "Venus", ("Earth", "Mars", "Jupiter", "Saturn", "Uranus"), 5),
        # Edge cases
        ("Earth", "Earth", (), 0),
        ("Mars", "Earth", (), 0),
        ("Jupiter", "Makemake", (), 0, True)  # Invalid
    ]
    
    passed = 0
    for test in test_cases:
        p1, p2, expected, exp_count, *invalid = test + (False,)
        invalid = invalid[0] if invalid else False
        
        # Set inputs
        dut.planet1.value = planets.get(p1, 8)  # Invalid if >7
        dut.planet2.value = planets.get(p2, 8)
        await Timer(1, "ns")
        
        # Check invalid
        if invalid or p1 not in planets or p2 not in planets:
            if dut.invalid.value != 1:
                dut._log.error(f"FAIL {p1}/{p2}: Invalid not set")
                continue
            passed += 1
            continue
        
        # Check output
        error = False
        for i in range(5):
            val = dut.planets[i].value.integer
            exp = planets[expected[i]] if i < len(expected) else 0
            if i < len(expected) and val != exp:
                dut._log.error(f"FAIL {p1}->{p2}: Slot {i}={val} not {exp}")
                error = True
        
        if dut.count.value != exp_count:
            dut._log.error(f"FAIL {p1}->{p2}: Count {dut.count.value} != {exp_count}")
            error = True
        
        if not error:
            passed += 1
            dut._log.info(f"PASS {p1}/{p2}: {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")