import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_loop_checker(dut):
    DATA_WIDTH = 8
    MAX_POINTS = 8
    
    test_cases = [
        (4, [(1,1), (1,3), (3,1), (3,3)], 1, "Square"),
        (4, [(0,0), (0,2), (2,0), (2,2)], 1, "Origin square"),
        (6, [(1,1), (1,3), (2,2), (2,3), (3,1), (3,2)], 1, "Complex valid"),
        (3, [(1,1), (1,2), (2,1)], 0, "Odd count"),
        (4, [(1,1), (1,2), (2,1), (2,3)], 0, "Disconnected y"),
        (4, [(1,1), (2,2), (3,3), (4,4)], 0, "Diagonal"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, points, expected, desc) in enumerate(test_cases):
        dut.n.value = n
        
        for j in range(MAX_POINTS):
            if j < len(points):
                x_val = clamp_to_width(points[j][0], DATA_WIDTH)
                y_val = clamp_to_width(points[j][1], DATA_WIDTH)
            else:
                x_val = 0
                y_val = 0
            getattr(dut, f'x{j}').value = x_val
            getattr(dut, f'y{j}').value = y_val
        
        await Timer(100, units='ns')
        
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"Test {i} FAIL: result undefined")
            failed += 1
            continue
            
        result = safe_int(dut.result.value)
        
        if result == expected:
            cocotb.log.info(f"Test {i} PASS: {desc}")
            passed += 1
        else:
            cocotb.log.error(f"Test {i} FAIL: {desc}, expected {expected}, got {result}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")