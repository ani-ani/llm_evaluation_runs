import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer
import math

# Q16.16 conversion utilities
def float_to_q16(value):
    return int(value * 65536)

def q16_to_float(value):
    return value / 65536.0

# Distance calculation for testbench
def calc_distance(x1, y1, x2, y2):
    return math.sqrt((x2 - x1)**2 + (y2 - y1)**2)

@cocotb.test()
async def test_conveyor_path_finder(dut):
    """Test conveyor path finder with various configurations"""
    
    # Test case 1: Sample Input 1 adapted
    # A(60,0) -> B(50,170), Conveyor C(40,0) -> D(0,0)
    ax, ay = 60.0, 0.0
    bx, by = 50.0, 170.0
    cx, cy = 40.0, 0.0
    dx, dy = 0.0, 0.0
    
    dut.ax_q16.value = float_to_q16(ax)
    dut.ay_q16.value = float_to_q16(ay)
    dut.bx_q16.value = float_to_q16(bx)
    dut.by_q16.value = float_to_q16(by)
    dut.cx_q16.value = float_to_q16(cx)
    dut.cy_q16.value = float_to_q16(cy)
    dut.dx_q16.value = float_to_q16(dx)
    dut.dy_q16.value = float_to_q16(dy)
    
    await Timer(10, units='ns')
    
    # Calculate expected values
    direct_dist = calc_distance(ax, ay, bx, by)
    assisted_dist = calc_distance(ax, ay, cx, cy) + calc_distance(cx, cy, dx, dy)/2.0 + calc_distance(dx, dy, bx, by)
    expected_time = min(direct_dist, assisted_dist)
    
    result_q16 = dut.min_time_q16.value
    result_time = q16_to_float(int(result_q16))
    
    error = abs(result_time - expected_time)
    print(f"Test 1: Direct={direct_dist:.4f}s, Assisted={assisted_dist:.4f}s, Expected={expected_time:.4f}s, Got={result_time:.4f}s, Error={error:.6f}")
    assert error < 0.1, f"Test 1 failed: error {error} > 0.1"
    
    # Test case 2: Simple horizontal walk with vertical conveyor
    ax, ay = 0.0, 1.0
    bx, by = 4.0, 1.0
    cx, cy = 0.0, 0.0
    dx, dy = 4.0, 0.0
    
    dut.ax_q16.value = float_to_q16(ax)
    dut.ay_q16.value = float_to_q16(ay)
    dut.bx_q16.value = float_to_q16(bx)
    dut.by_q16.value = float_to_q16(by)
    dut.cx_q16.value = float_to_q16(cx)
    dut.cy_q16.value = float_to_q16(cy)
    dut.dx_q16.value = float_to_q16(dx)
    dut.dy_q16.value = float_to_q16(dy)
    
    await Timer(10, units='ns')
    
    direct_dist = calc_distance(ax, ay, bx, by)
    assisted_dist = calc_distance(ax, ay, cx, cy) + calc_distance(cx, cy, dx, dy)/2.0 + calc_distance(dx, dy, bx, by)
    expected_time = min(direct_dist, assisted_dist)
    
    result_q16 = dut.min_time_q16.value
    result_time = q16_to_float(int(result_q16))
    
    error = abs(result_time - expected_time)
    print(f"Test 2: Direct={direct_dist:.4f}s, Assisted={assisted_dist:.4f}s, Expected={expected_time:.4f}s, Got={result_time:.4f}s, Error={error:.6f}")
    assert error < 0.1, f"Test 2 failed: error {error} > 0.1"
    
    # Test case 3: Direct is better
    ax, ay = 0.0, 0.0
    bx, by = 1.0, 0.0
    cx, cy = 0.0, 5.0
    dx, dy = 1.0, 5.0
    
    dut.ax_q16.value = float_to_q16(ax)
    dut.ay_q16.value = float_to_q16(ay)
    dut.bx_q16.value = float_to_q16(bx)
    dut.by_q16.value = float_to_q16(by)
    dut.cx_q16.value = float_to_q16(cx)
    dut.cy_q16.value = float_to_q16(cy)
    dut.dx_q16.value = float_to_q16(dx)
    dut.dy_q16.value = float_to_q16(dy)
    
    await Timer(10, units='ns')
    
    direct_dist = calc_distance(ax, ay, bx, by)
    assisted_dist = calc_distance(ax, ay, cx, cy) + calc_distance(cx, cy, dx, dy)/2.0 + calc_distance(dx, dy, bx, by)
    expected_time = min(direct_dist, assisted_dist)
    
    result_q16 = dut.min_time_q16.value
    result_time = q16_to_float(int(result_q16))
    
    error = abs(result_time - expected_time)
    print(f"Test 3: Direct={direct_dist:.4f}s, Assisted={assisted_dist:.4f}s, Expected={expected_time:.4f}s, Got={result_time:.4f}s, Error={error:.6f}")
    assert error < 0.1, f"Test 3 failed: error {error} > 0.1"
    
    # Test case 4: Long diagonal with helpful conveyor
    ax, ay = 0.0, 0.0
    bx, by = 100.0, 100.0
    cx, cy = 0.0, 50.0
    dx, dy = 100.0, 50.0
    
    dut.ax_q16.value = float_to_q16(ax)
    dut.ay_q16.value = float_to_q16(ay)
    dut.bx_q16.value = float_to_q16(bx)
    dut.by_q16.value = float_to_q16(by)
    dut.cx_q16.value = float_to_q16(cx)
    dut.cy_q16.value = float_to_q16(cy)
    dut.dx_q16.value = float_to_q16(dx)
    dut.dy_q16.value = float_to_q16(dy)
    
    await Timer(10, units='ns')
    
    direct_dist = calc_distance(ax, ay, bx, by)
    assisted_dist = calc_distance(ax, ay, cx, cy) + calc_distance(cx, cy, dx, dy)/2.0 + calc_distance(dx, dy, bx, by)
    expected_time = min(direct_dist, assisted_dist)
    
    result_q16 = dut.min_time_q16.value
    result_time = q16_to_float(int(result_q16))
    
    error = abs(result_time - expected_time)
    print(f"Test 4: Direct={direct_dist:.4f}s, Assisted={assisted_dist:.4f}s, Expected={expected_time:.4f}s, Got={result_time:.4f}s, Error={error:.6f}")
    assert error < 0.1, f"Test 4 failed: error {error} > 0.1"
    
    # Test case 5: Edge case - all same
    ax, ay = 50.0, 50.0
    bx, by = 50.0, 50.0
    cx, cy = 60.0, 60.0
    dx, dy = 70.0, 70.0
    
    dut.ax_q16.value = float_to_q16(ax)
    dut.ay_q16.value = float_to_q16(ay)
    dut.bx_q16.value = float_to_q16(bx)
    dut.by_q16.value = float_to_q16(by)
    dut.cx_q16.value = float_to_q16(cx)
    dut.cy_q16.value = float_to_q16(cy)
    dut.dx_q16.value = float_to_q16(dx)
    dut.dy_q16.value = float_to_q16(dy)
    
    await Timer(10, units='ns')
    
    direct_dist = calc_distance(ax, ay, bx, by)
    assisted_dist = calc_distance(ax, ay, cx, cy) + calc_distance(cx, cy, dx, dy)/2.0 + calc_distance(dx, dy, bx, by)
    expected_time = min(direct_dist, assisted_dist)
    
    result_q16 = dut.min_time_q16.value
    result_time = q16_to_float(int(result_q16))
    
    error = abs(result_time - expected_time)
    print(f"Test 5: Direct={direct_dist:.4f}s, Assisted={assisted_dist:.4f}s, Expected={expected_time:.4f}s, Got={result_time:.4f}s, Error={error:.6f}")
    assert error < 0.1, f"Test 5 failed: error {error} > 0.1"
    
    print("
All 5 tests passed!")
