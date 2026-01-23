import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import random

# Helper function to convert float to Q16.16 fixed-point
def float_to_q16_16(f):
    return int(f * 65536) & 0xFFFFFFFF

# Helper function to convert Q16.16 to float
def q16_16_to_float(q):
    if q & 0x80000000:  # Sign bit
        return -((~q + 1) / 65536.0)
    return q / 65536.0

# Reference calculation in Python
def calculate_min_pack_length(num_cheetahs, times, velocities):
    # Find latest start time
    max_t = max(times[:num_cheetahs])
    
    # Generate critical times
    critical_times = []
    
    # Add all start times
    for i in range(num_cheetahs):
        if times[i] >= max_t:
            critical_times.append(times[i])
    
    # Add intersection times for all pairs
    for i in range(num_cheetahs):
        for j in range(i+1, num_cheetahs):
            if velocities[i] != velocities[j]:
                # t = (v_i*t_i - v_j*t_j) / (v_i - v_j)
                numerator = velocities[i] * times[i] - velocities[j] * times[j]
                denominator = velocities[i] - velocities[j]
                t_intersect = numerator / denominator
                if t_intersect >= max_t:
                    critical_times.append(t_intersect)
    
    # Add a time slightly after max_t to capture initial state
    critical_times.append(max_t + 0.0001)
    
    # Remove duplicates and sort
    critical_times = sorted(list(set(critical_times)))
    
    min_length = float('inf')
    
    # Evaluate each critical time
    for t in critical_times:
        positions = []
        for i in range(num_cheetahs):
            if t >= times[i]:
                pos = velocities[i] * (t - times[i])
                positions.append(pos)
        
        if positions:
            pack_length = max(positions) - min(positions)
            if pack_length < min_length:
                min_length = pack_length
    
    return min_length

@cocotb.test()
async def test_cheetah_pack_minimum(dut):
    """Test cheetah pack minimum calculation"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_cheetahs.value = 0
    for i in range(4):
        dut.start_times[i].value = 0
        dut.velocities[i].value = 0
    
    await RisingEdge(dut.clk)
    await Timer(1, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Two cheetahs, same speed and start time
    dut._log.info("Test 1: Two cheetahs, same speed and start time")
    dut.num_cheetahs.value = 2
    dut.start_times[0].value = float_to_q16_16(1.0)
    dut.velocities[0].value = float_to_q16_16(1.0)
    dut.start_times[1].value = float_to_q16_16(1.0)
    dut.velocities[1].value = float_to_q16_16(1.0)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1, "Done signal not asserted"
    result = q16_16_to_float(int(dut.min_pack_length.value))
    expected = calculate_min_pack_length(2, [1.0, 1.0], [1.0, 1.0])
    dut._log.info(f"Result: {result}, Expected: {expected}")
    assert abs(result - expected) < 0.1, f"Test 1 failed: {result} vs {expected}"
    
    # Wait a bit before next test
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test Case 2: Two cheetahs, different start times
    dut._log.info("Test 2: Two cheetahs, different start times")
    dut.num_cheetahs.value = 2
    dut.start_times[0].value = float_to_q16_16(1.0)
    dut.velocities[0].value = float_to_q16_16(99999.0)
    dut.start_times[1].value = float_to_q16_16(99999.0)
    dut.velocities[1].value = float_to_q16_16(99999.0)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1, "Done signal not asserted"
    result = q16_16_to_float(int(dut.min_pack_length.value))
    expected = calculate_min_pack_length(2, [1.0, 99999.0], [99999.0, 99999.0])
    dut._log.info(f"Result: {result}, Expected: {expected}")
    assert abs(result - expected) < 10000.0, f"Test 2 failed: {result} vs {expected}"
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test Case 3: Three cheetahs, speeds increasing
    dut._log.info("Test 3: Three cheetahs, increasing speeds")
    dut.num_cheetahs.value = 3
    dut.start_times[0].value = float_to_q16_16(1.0)
    dut.velocities[0].value = float_to_q16_16(1.0)
    dut.start_times[1].value = float_to_q16_16(3.0)
    dut.velocities[1].value = float_to_q16_16(2.0)
    dut.start_times[2].value = float_to_q16_16(4.0)
    dut.velocities[2].value = float_to_q16_16(3.0)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1, "Done signal not asserted"
    result = q16_16_to_float(int(dut.min_pack_length.value))
    expected = calculate_min_pack_length(3, [1.0, 3.0, 4.0], [1.0, 2.0, 3.0])
    dut._log.info(f"Result: {result}, Expected: {expected}")
    assert abs(result - expected) < 0.1, f"Test 3 failed: {result} vs {expected}"
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test Case 4: Single cheetah
    dut._log.info("Test 4: Single cheetah")
    dut.num_cheetahs.value = 1
    dut.start_times[0].value = float_to_q16_16(5.0)
    dut.velocities[0].value = float_to_q16_16(10.0)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1, "Done signal not asserted"
    result = q16_16_to_float(int(dut.min_pack_length.value))
    expected = 0.0  # Single cheetah, length is always 0
    dut._log.info(f"Result: {result}, Expected: {expected}")
    assert abs(result - expected) < 0.1, f"Test 4 failed: {result} vs {expected}"
    
    # Summary
    dut._log.info("4/4 tests passed")