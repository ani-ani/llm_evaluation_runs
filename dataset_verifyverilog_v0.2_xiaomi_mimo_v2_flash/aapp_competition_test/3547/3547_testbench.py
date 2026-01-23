import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

def float_to_q16_16(value):
    """Convert float to Q16.16 fixed-point representation"""
    return int(value * 65536) & 0xFFFFFFFF

def q16_16_to_float(value):
    """Convert Q16.16 fixed-point to float"""
    if value & 0x80000000:  # negative
        return -((0x100000000 - value) / 65536.0)
    else:
        return value / 65536.0

def calculate_union_area(rects):
    """Calculate union area of rectangles in Python for verification"""
    if not rects:
        return 0.0
    
    # Collect all unique x and y coordinates
    xs = sorted(set([r[0] for r in rects] + [r[2] for r in rects]))
    ys = sorted(set([r[1] for r in rects] + [r[3] for r in rects]))
    
    total_area = 0.0
    for i in range(len(xs) - 1):
        for j in range(len(ys) - 1):
            x1, x2 = xs[i], xs[i + 1]
            y1, y2 = ys[j], ys[j + 1]
            
            # Check if this small rectangle is covered by any input rectangle
            covered = False
            for rx1, ry1, rx2, ry2 in rects:
                if x1 >= rx1 and x2 <= rx2 and y1 >= ry1 and y2 <= ry2:
                    covered = True
                    break
            
            if covered:
                total_area += (x2 - x1) * (y2 - y1)
    
    return total_area

@cocotb.test()
async def test_rect_area_calculator(dut):
    """Test rectangle area calculator with multiple test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Initialize inputs
    dut.rst_n.value = 1
    dut.start.value = 0
    dut.rect_valid.value = 0
    dut.x1.value = 0
    dut.y1.value = 0
    dut.x2.value = 0
    dut.y2.value = 0
    dut.rect_idx.value = 0
    
    # Reset
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: 2 rectangles (overlapping)
    # Rectangle 1: 0,0 to 100,100
    # Rectangle 2: 30,30 to 60,60
    rects1 = [(0.0, 0.0, 100.0, 100.0), (30.0, 30.0, 60.0, 60.0)]
    expected_area1 = 10000.0
    
    # Load rectangles
    for i, (x1, y1, x2, y2) in enumerate(rects1):
        dut.x1.value = float_to_q16_16(x1)
        dut.y1.value = float_to_q16_16(y1)
        dut.x2.value = float_to_q16_16(x2)
        dut.y2.value = float_to_q16_16(y2)
        dut.rect_idx.value = i
        dut.rect_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.rect_valid.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (should be done within 64 cycles)
    timeout = 100
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result1 = int(dut.total_area.value)
    result_float1 = q16_16_to_float(result1)
    
    print(f"Test 1 - Expected: {expected_area1:.2f}, Got: {result_float1:.2f}")
    assert abs(result_float1 - expected_area1) < 0.01, f"Test 1 failed: expected {expected_area1}, got {result_float1}"
    assert dut.done.value == 1, "Test 1: done signal not asserted"
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2: 2 rectangles (crossing)
    # Rectangle 1: 0.00,100.00 to 300.00,200.00
    # Rectangle 2: 100.00,0.00 to 200.00,300.00
    rects2 = [(0.0, 100.0, 300.0, 200.0), (100.0, 0.0, 200.0, 300.0)]
    expected_area2 = 50000.0
    
    for i, (x1, y1, x2, y2) in enumerate(rects2):
        dut.x1.value = float_to_q16_16(x1)
        dut.y1.value = float_to_q16_16(y1)
        dut.x2.value = float_to_q16_16(x2)
        dut.y2.value = float_to_q16_16(y2)
        dut.rect_idx.value = i
        dut.rect_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.rect_valid.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 100
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result2 = int(dut.total_area.value)
    result_float2 = q16_16_to_float(result2)
    
    print(f"Test 2 - Expected: {expected_area2:.2f}, Got: {result_float2:.2f}")
    assert abs(result_float2 - expected_area2) < 0.01, f"Test 2 failed: expected {expected_area2}, got {result_float2}"
    assert dut.done.value == 1, "Test 2: done signal not asserted"
    
    # Test case 3: 3 rectangles (one completely overlapped)
    # Rectangle 1: 0,0 to 50,50
    # Rectangle 2: 10,10 to 40,40
    # Rectangle 3: 60,60 to 70,70
    rects3 = [(0.0, 0.0, 50.0, 50.0), (10.0, 10.0, 40.0, 40.0), (60.0, 60.0, 70.0, 70.0)]
    expected_area3 = 2500.0 + 100.0  # 2500 + 100 = 2600
    
    # Reset again
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for i, (x1, y1, x2, y2) in enumerate(rects3):
        dut.x1.value = float_to_q16_16(x1)
        dut.y1.value = float_to_q16_16(y1)
        dut.x2.value = float_to_q16_16(x2)
        dut.y2.value = float_to_q16_16(y2)
        dut.rect_idx.value = i
        dut.rect_valid.value = 1
        await RisingEdge(dut.clk)
    
    # Fill remaining slots with dummy data or mark invalid
    for i in range(len(rects3), 4):
        dut.rect_idx.value = i
        dut.rect_valid.value = 0  # Mark invalid
        await RisingEdge(dut.clk)
    
    dut.rect_valid.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 100
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result3 = int(dut.total_area.value)
    result_float3 = q16_16_to_float(result3)
    
    print(f"Test 3 - Expected: {expected_area3:.2f}, Got: {result_float3:.2f}")
    assert abs(result_float3 - expected_area3) < 0.01, f"Test 3 failed: expected {expected_area3}, got {result_float3}"
    assert dut.done.value == 1, "Test 3: done signal not asserted"
    
    # Test case 4: Non-overlapping rectangles
    # Rectangle 1: 0,0 to 10,10
    # Rectangle 2: 20,20 to 30,30
    rects4 = [(0.0, 0.0, 10.0, 10.0), (20.0, 20.0, 30.0, 30.0)]
    expected_area4 = 100.0 + 100.0 = 200.0
    
    # Reset again
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for i, (x1, y1, x2, y2) in enumerate(rects4):
        dut.x1.value = float_to_q16_16(x1)
        dut.y1.value = float_to_q16_16(y1)
        dut.x2.value = float_to_q16_16(x2)
        dut.y2.value = float_to_q16_16(y2)
        dut.rect_idx.value = i
        dut.rect_valid.value = 1
        await RisingEdge(dut.clk)
    
    # Fill remaining slots
    for i in range(len(rects4), 4):
        dut.rect_idx.value = i
        dut.rect_valid.value = 0
        await RisingEdge(dut.clk)
    
    dut.rect_valid.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 100
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result4 = int(dut.total_area.value)
    result_float4 = q16_16_to_float(result4)
    
    print(f"Test 4 - Expected: {expected_area4:.2f}, Got: {result_float4:.2f}")
    assert abs(result_float4 - expected_area4) < 0.01, f"Test 4 failed: expected {expected_area4}, got {result_float4}"
    assert dut.done.value == 1, "Test 4: done signal not asserted"
    
    print("All 4 tests passed!")
