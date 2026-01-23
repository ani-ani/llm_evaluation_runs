import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

# Fixed-point conversion helpers
def float_to_q1616(value):
    return int(value * 65536)

def q1616_to_float(value):
    return value / 65536.0

@cocotb.test()
async def test_luggage_speed_basic(dut):
    """Test basic case: 2 bags, 3m belt, expected speed = 2.0 m/s"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_luggage.value = 0
    dut.belt_length.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Setup test case: 2 bags at 0.00 and 2.00, belt length 3
    dut.num_luggage.value = 2
    dut.belt_length.value = 3
    dut.positions_0.value = float_to_q1616(0.00)
    dut.positions_1.value = float_to_q1616(2.00)
    # Set unused positions to 0
    for i in range(2, 8):
        getattr(dut, f'positions_{i}').value = 0
    
    # Start computation
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max 2000 cycles)
    max_wait = 2000
    for i in range(max_wait):
        await RisingEdge(dut.clk)
        if dut.valid.value == 1 or dut.no_fika.value == 1:
            break
    else:
        raise TimeoutError("Computation did not complete in time")
    
    # Check result
    if dut.no_fika.value == 1:
        assert False, "Should have found valid speed"
    
    result_speed = q1616_to_float(int(dut.max_speed.value))
    expected = 2.0
    
    print(f"Test 1 - Result: {result_speed:.6f}, Expected: {expected:.6f}")
    assert abs(result_speed - expected) < 0.001, f"Speed mismatch: {result_speed} vs {expected}"

@cocotb.test()
async def test_luggage_speed_complex(dut):
    """Test case: 3 bags, 4m belt, expected speed = 0.5 m/s"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Setup: 3 bags at 0.05, 1.00, 3.50, belt length 4
    dut.num_luggage.value = 3
    dut.belt_length.value = 4
    dut.positions_0.value = float_to_q1616(0.05)
    dut.positions_1.value = float_to_q1616(1.00)
    dut.positions_2.value = float_to_q1616(3.50)
    for i in range(3, 8):
        getattr(dut, f'positions_{i}').value = 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    max_wait = 2000
    for i in range(max_wait):
        await RisingEdge(dut.clk)
        if dut.valid.value == 1 or dut.no_fika.value == 1:
            break
    
    if dut.no_fika.value == 1:
        assert False, "Should have found valid speed"
    
    result_speed = q1616_to_float(int(dut.max_speed.value))
    expected = 0.5
    
    print(f"Test 2 - Result: {result_speed:.6f}, Expected: {expected:.6f}")
    assert abs(result_speed - expected) < 0.01, f"Speed mismatch: {result_speed} vs {expected}"

@cocotb.test()
async def test_luggage_speed_collision_imminent(dut):
    """Test case where bags are very close - should give low speed"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # 2 bags at 0.00 and 0.50 on 16m belt
    dut.num_luggage.value = 2
    dut.belt_length.value = 16
    dut.positions_0.value = float_to_q1616(0.00)
    dut.positions_1.value = float_to_q1616(0.50)
    for i in range(2, 8):
        getattr(dut, f'positions_{i}').value = 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    max_wait = 2000
    for i in range(max_wait):
        await RisingEdge(dut.clk)
        if dut.valid.value == 1 or dut.no_fika.value == 1:
            break
    
    if dut.no_fika.value == 1:
        print("Test 3 - No fika (expected for very close bags)")
    else:
        result_speed = q1616_to_float(int(dut.max_speed.value))
        print(f"Test 3 - Result: {result_speed:.6f}")
        # Should be low speed
        assert result_speed < 2.0, f"Speed too high for close bags: {result_speed}"

@cocotb.test()
async def test_luggage_speed_single_bag(dut):
    """Test case with single bag - should allow max speed"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    dut.num_luggage.value = 1
    dut.belt_length.value = 10
    dut.positions_0.value = float_to_q1616(5.00)
    for i in range(1, 8):
        getattr(dut, f'positions_{i}').value = 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    max_wait = 2000
    for i in range(max_wait):
        await RisingEdge(dut.clk)
        if dut.valid.value == 1 or dut.no_fika.value == 1:
            break
    
    if dut.no_fika.value == 1:
        assert False, "Single bag should always work"
    
    result_speed = q1616_to_float(int(dut.max_speed.value))
    expected = 10.0
    
    print(f"Test 4 - Result: {result_speed:.6f}, Expected: {expected:.6f}")
    # Should be close to max speed
    assert result_speed >= 9.0, f"Speed too low for single bag: {result_speed}"

@cocotb.test()
async def test_luggage_speed_max_cases(dut):
    """Test multiple bags spread across belt - should find reasonable speed"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # 5 bags on 8m belt
    dut.num_luggage.value = 5
    dut.belt_length.value = 8
    dut.positions_0.value = float_to_q1616(0.00)
    dut.positions_1.value = float_to_q1616(1.50)
    dut.positions_2.value = float_to_q1616(3.00)
    dut.positions_3.value = float_to_q1616(4.50)
    dut.positions_4.value = float_to_q1616(6.00)
    for i in range(5, 8):
        getattr(dut, f'positions_{i}').value = 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    max_wait = 2000
    for i in range(max_wait):
        await RisingEdge(dut.clk)
        if dut.valid.value == 1 or dut.no_fika.value == 1:
            break
    
    if dut.no_fika.value == 1:
        print("Test 5 - No fika")
    else:
        result_speed = q1616_to_float(int(dut.max_speed.value))
        print(f"Test 5 - Result: {result_speed:.6f}")
        assert 0.1 <= result_speed <= 10.0, f"Speed out of range: {result_speed}"

print("
=== Summary ===")
print("All tests completed. Check individual test results above.")
print("Expected behavior:")
print("- Test 1: Speed ≈ 2.0 m/s")
print("- Test 2: Speed ≈ 0.5 m/s")
print("- Test 3: Low speed (< 2.0) or no fika")
print("- Test 4: High speed (≥ 9.0)")
print("- Test 5: Valid speed within [0.1, 10.0]")