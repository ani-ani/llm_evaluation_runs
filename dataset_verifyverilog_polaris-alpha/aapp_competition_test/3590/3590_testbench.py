import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import math

@cocotb.test()
async def test_polygon_cutter(dut):
    # Create 25MHz clock
    clock = Clock(dut.clk, 40, units="ns")
    cocotb.start_soon(clock.start())

    # Convert float to Q8.8 fixed-point
    def to_q8_8(val):
        return int(val * 256)
    
    # Fixed-point square helper
    async def fp_dist(x1, y1, x2, y2):
        dx = (x1 - x2) // 256
        dy = (y1 - y2) // 256
        return math.sqrt(dx**2 + dy**2)
    
    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: Sample input (scaled to fixed-point)
    test_vertices = [
        { # Test case 1: Sample Input
            "a_count": 4,
            "a_x": [to_q8_8(x) for x in [0, 0, 15, 15]],
            "a_y": [to_q8_8(y) for y in [0, 14, 14, 0]],
            "b_count": 4,
            "b_x": [to_q8_8(x) for x in [8, 4, 7, 11]],
            "b_y": [to_q8_8(y) for y in [3, 6, 10, 7]],
            "expected": 40.0 * 65536  # Q16.16 expected (40.0)
        },
        { # Test case 2: Simplified square
            "a_count": 4,
            "a_x": [to_q8_8(x) for x in [-100, -100, 100, 100]],
            "a_y": [to_q8_8(y) for y in [-100, 100, 100, -100]],
            "b_count": 4,
            "b_x": [to_q8_8(x) for x in [-10, -10, 10, 10]],
            "b_y": [to_q8_8(y) for y in [-10, 10, 10, -10]],
            "expected": (320.0) * 65536  # Approximate expectation
        }
    ]
    
    passed = 0
    tolerance = 0.01 * 65536  # 1% tolerance in Q16.16
    
    for test in test_vertices:
        # Load inputs
        dut.start.value = 0
        dut.a_count.value = test["a_count"]
        dut.b_count.value = test["b_count"]
        
        for i in range(8):
            dut.a_x[i].value = test["a_x"][i] if i < len(test["a_x"]) else 0
            dut.a_y[i].value = test["a_y"][i] if i < len(test["a_y"]) else 0
            dut.b_x[i].value = test["b_x"][i] if i < len(test["b_x"]) else 0
            dut.b_y[i].value = test["b_y"][i] if i < len(test["b_y"]) else 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (20 cycles latency)
        for _ in range(21):
            await RisingEdge(dut.clk)
        
        # Check result
        actual = dut.total_cost.value.signed_integer
        expected_q16 = test["expected"]
        if abs(actual - expected_q16) <= tolerance:
            passed += 1
        else:
            dut._log.error(f"Test failed: Got {actual/65536:.6f}, Expected {expected_q16/65536:.6f}")
        
    # Final result
    total_tests = len(test_vertices)
    dut._log.info(f"{passed}/{total_tests} tests passed")
    assert passed == total_tests