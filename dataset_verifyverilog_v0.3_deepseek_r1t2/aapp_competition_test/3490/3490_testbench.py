import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def to_fixed(x, frac_bits=16):
    return int(x * (1 << frac_bits))

def from_fixed(fixed, frac_bits=16):
    return fixed / (1 << frac_bits)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_crash_detection(dut):
    # Test cases: (description, x1, y1, r1, x2, y2, r2, expected_crash)
    test_cases = [
        ("No crash - parallel brooms, no overlap", 0.0, 0.0, 0.0, 0.0, 1.5, 0.0, 0),
        ("Crash - opposite brooms, overlap", 0.0, 0.0, 0.0, 0.0, 1.5, 3.14159, 1),
        ("No crash - distant brooms", 0.0, 0.0, 0.0, 5.0, 0.0, 0.0, 0),
        ("Crash - same position", 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1),
        ("No crash - small angle, close", 0.0, 0.0, 0.0, 0.1, 0.1, 0.1, 0),
    ]
    
    passed = 0
    failed = 0
    
    for i, (desc, x1, y1, r1, x2, y2, r2, expected) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: {desc}")
        
        # Convert to fixed-point
        dut.x1.value = to_fixed(x1)
        dut.y1.value = to_fixed(y1)
        dut.r1.value = to_fixed(r1)
        dut.x2.value = to_fixed(x2)
        dut.y2.value = to_fixed(y2)
        dut.r2.value = to_fixed(r2)
        
        # Wait for combinational logic
        await Timer(100, units='ns')
        
        # Check result
        if not is_value_defined(dut.crash.value):
            dut._log.error(f"  FAIL: Output is undefined")
            failed += 1
            continue
        
        result = int(dut.crash.value)
        
        if result != expected:
            dut._log.error(f"  FAIL: Expected {expected}, got {result}")
            failed += 1
        else:
            dut._log.info(f"  PASS: result = {result}")
            passed += 1
    
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
