import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import math

def float_to_q16_16(value):
    """Convert float to Q16.16 fixed-point representation"""
    return int(value * 65536) & 0xFFFFFFFF

def q16_16_to_float(value):
    """Convert Q16.16 to float (for verification)"""
    if value & 0x80000000:  # negative
        return (value - 0x100000000) / 65536.0
    return value / 65536.0

def intersects_ray_rectangle(x0, y0, x1, y1, rx1, ry1, rx2, ry2, beam_len):
    """Check if ray segment from (x0,y0) to (x1,y1) intersects rectangle"""
    # First check if endpoint is within length limit
    dx = x1 - x0
    dy = y1 - y0
    dist_sq = dx*dx + dy*dy
    if dist_sq > beam_len*beam_len * 1.1:  # small tolerance
        return False
    
    # Check if segment intersects rectangle using simple line clipping
    # Check if segment passes through or touches the rectangle
    
    # Quick check: if both endpoints are on same side of all rectangle edges, no intersect
    if (x1 < rx1 and x0 < rx1) or (x1 > rx2 and x0 > rx2) or \
       (y1 < ry1 and y0 < ry1) or (y1 > ry2 and y0 > ry2):
        return False
    
    # Check segment-rectangle intersection by testing segment against each edge
    # Edge 1: x = rx1, y in [ry1, ry2]
    if x0 != x1:
        t = (rx1 - x0) / (x1 - x0)
        if 0 <= t <= 1:
            y = y0 + t * (y1 - y0)
            if ry1 <= y <= ry2:
                return True
    
    # Edge 2: x = rx2, y in [ry1, ry2]
    if x0 != x1:
        t = (rx2 - x0) / (x1 - x0)
        if 0 <= t <= 1:
            y = y0 + t * (y1 - y0)
            if ry1 <= y <= ry2:
                return True
    
    # Edge 3: y = ry1, x in [rx1, rx2]
    if y0 != y1:
        t = (ry1 - y0) / (y1 - y0)
        if 0 <= t <= 1:
            x = x0 + t * (x1 - x0)
            if rx1 <= x <= rx2:
                return True
    
    # Edge 4: y = ry2, x in [rx1, rx2]
    if y0 != y1:
        t = (ry2 - y0) / (y1 - y0)
        if 0 <= t <= 1:
            x = x0 + t * (x1 - x0)
            if rx1 <= x <= rx2:
                return True
    
    # Check if rectangle corner is on segment
    for corner in [(rx1, ry1), (rx1, ry2), (rx2, ry1), (rx2, ry2)]:
        cx, cy = corner
        # Check if (cx,cy) is on segment (x0,y0)-(x1,y1)
        cross = (cx - x0) * (y1 - y0) - (cy - y0) * (x1 - x0)
        if abs(cross) < 0.0001:  # collinear
            dot = (cx - x0) * (x1 - x0) + (cy - y0) * (y1 - y0)
            if 0 <= dot <= (x1 - x0)**2 + (y1 - y0)**2:
                return True
    
    return False

@cocotb.test()
async def test_phaser_optimal(dut):
    """Test the phaser_optimal module"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.room_count.value = 0
    for i in range(8):
        dut.room_x1[i].value = 0
        dut.room_y1[i].value = 0
        dut.room_x2[i].value = 0
        dut.room_y2[i].value = 0
    dut.beam_length.value = 0
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: Sample from problem
    rooms_1 = [
        (2, 1, 4, 5),
        (5, 1, 12, 4),
        (5, 5, 9, 10),
        (1, 6, 4, 10),
        (2, 11, 7, 14)
    ]
    beam_len_1 = 8
    
    # Load inputs
    dut.room_count.value = 5
    for i, (x1, y1, x2, y2) in enumerate(rooms_1):
        dut.room_x1[i].value = float_to_q16_16(x1)
        dut.room_y1[i].value = float_to_q16_16(y1)
        dut.room_x2[i].value = float_to_q16_16(x2)
        dut.room_y2[i].value = float_to_q16_16(y2)
    dut.beam_length.value = float_to_q16_16(beam_len_1)
    
    # Start computation
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 600:
        await RisingEdge(dut.clk)
        timeout += 1
    
    result_1 = int(dut.max_rooms.value)
    print(f"Test 1: Expected 4, Got {result_1}")
    assert result_1 == 4, f"Test 1 failed: expected 4, got {result_1}"
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2
    rooms_2 = [
        (2, 2, 3, 3),
        (5, 3, 6, 4),
        (6, 6, 7, 7)
    ]
    beam_len_2 = 6
    
    dut.room_count.value = 3
    for i, (x1, y1, x2, y2) in enumerate(rooms_2):
        dut.room_x1[i].value = float_to_q16_16(x1)
        dut.room_y1[i].value = float_to_q16_16(y1)
        dut.room_x2[i].value = float_to_q16_16(x2)
        dut.room_y2[i].value = float_to_q16_16(y2)
    dut.beam_length.value = float_to_q16_16(beam_len_2)
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 600:
        await RisingEdge(dut.clk)
        timeout += 1
    
    result_2 = int(dut.max_rooms.value)
    print(f"Test 2: Expected 3, Got {result_2}")
    assert result_2 == 3, f"Test 2 failed: expected 3, got {result_2}"
    
    # Edge case: single room
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.room_count.value = 1
    dut.room_x1[0].value = float_to_q16_16(10)
    dut.room_y1[0].value = float_to_q16_16(10)
    dut.room_x2[0].value = float_to_q16_16(20)
    dut.room_y2[0].value = float_to_q16_16(20)
    dut.beam_length.value = float_to_q16_16(5)
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 600:
        await RisingEdge(dut.clk)
        timeout += 1
    
    result_3 = int(dut.max_rooms.value)
    print(f"Test 3: Expected 1, Got {result_3}")
    assert result_3 == 1, f"Test 3 failed: expected 1, got {result_3}"
    
    print("All 3/3 tests passed!")