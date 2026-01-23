import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Helper functions
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

# Configuration
DATA_WIDTH = 8
RESULT_WIDTH = 16
INF = 0xFFFF

@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_dijkstra_3(dut):
    """Test the dijkstra_3 module with various cases"""
    
    # Test case 1: Unreachable cities
    cocotb.log.info("Test 1: Unreachable cities")
    dut.y1.value = 1
    dut.d1.value = 3
    dut.r1.value = 2
    dut.y2.value = 2
    dut.d2.value = 5
    dut.r2.value = 2
    dut.y3.value = 3
    dut.d3.value = 0
    dut.r3.value = 0
    
    await Timer(10, units='ns')
    
    dist2 = safe_int(dut.dist2.value)
    dist3 = safe_int(dut.dist3.value)
    
    if dist2 != INF:
        raise TestFailure(f"Test 1 failed: dist2 should be INF (0xFFFF), got {dist2:04X}")
    if dist3 != INF:
        raise TestFailure(f"Test 1 failed: dist3 should be INF (0xFFFF), got {dist3:04X}")
    
    cocotb.log.info(f"  PASS: dist2=0x{dist2:04X}, dist3=0x{dist3:04X}")
    
    # Test case 2: All cities reachable
    cocotb.log.info("Test 2: All cities reachable")
    dut.y1.value = 0
    dut.d1.value = 0
    dut.r1.value = 0
    dut.y2.value = 1
    dut.d2.value = 0
    dut.r2.value = 0
    dut.y3.value = 2
    dut.d3.value = 0
    dut.r3.value = 0
    
    await Timer(10, units='ns')
    
    dist2 = safe_int(dut.dist2.value)
    dist3 = safe_int(dut.dist3.value)
    
    if dist2 != 1:
        raise TestFailure(f"Test 2 failed: dist2 should be 1, got {dist2}")
    if dist3 != 2:
        raise TestFailure(f"Test 2 failed: dist3 should be 2, got {dist3}")
    
    cocotb.log.info(f"  PASS: dist2={dist2}, dist3={dist3}")
    
    # Test case 3: Via intermediate city
    cocotb.log.info("Test 3: Via intermediate city")
    dut.y1.value = 0
    dut.d1.value = 5
    dut.r1.value = 10
    dut.y2.value = 10
    dut.d2.value = 5
    dut.r2.value = 10
    dut.y3.value = 5
    dut.d3.value = 0
    dut.r3.value = 5
    
    await Timer(10, units='ns')
    
    dist2 = safe_int(dut.dist2.value)
    dist3 = safe_int(dut.dist3.value)
    
    # Direct: |0-10|=10>=5 -> 10+10=20
    # Via city3: |0-5|=5>=5 -> 10+5=15, then |5-10|=5>=0 -> 5+5=10, total 25
    # So direct is better: 20
    # For city3: direct: |0-5|=5>=5 -> 10+5=15
    if dist2 != 20:
        raise TestFailure(f"Test 3 failed: dist2 should be 20, got {dist2}")
    if dist3 != 15:
        raise TestFailure(f"Test 3 failed: dist3 should be 15, got {dist3}")
    
    cocotb.log.info(f"  PASS: dist2={dist2}, dist3={dist3}")
    
    cocotb.log.info("All tests passed!")