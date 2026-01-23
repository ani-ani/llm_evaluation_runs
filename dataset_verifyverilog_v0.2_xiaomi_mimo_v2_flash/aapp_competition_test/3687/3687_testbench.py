import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_downlink_verifier(dut):
    """Test downlink verification with adapted test cases"""
    
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Helper function to convert to Q16.16
    def to_q1616(value):
        return int(value * 65536)
    
    # Helper function to write array to dut
    async def write_array(dut, signal_name, values):
        for i, val in enumerate(values):
            getattr(dut, f"{signal_name}_{i}").value = val
    
    print("
=== Test 1: Possible case (adapted) ===")
    # Original: 2 windows, 2 queues, 2 sensors, capacities [3,3]
    # Window 1: downlink=5, sensor data [2,2]
    # Window 2: downlink=5, sensor data [2,2]
    # Adapted: 2 windows, 2 queues, 2 sensors, capacities [256,256]
    # Window 1: downlink=256, sensor data [100,100]
    # Window 2: downlink=256, sensor data [100,100]
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Set parameters
    dut.n_in.value = 2
    dut.q_in.value = 2
    dut.s_in.value = 2
    
    # Sensor queue map: sensor 0 -> queue 0, sensor 1 -> queue 1
    dut.sensor_queue_map_0.value = 0
    dut.sensor_queue_map_1.value = 1
    
    # Queue capacities (Q16.16: 256 = 0x01000000)
    dut.queue_capacities_0.value = to_q1616(256)
    dut.queue_capacities_1.value = to_q1616(256)
    
    # Window data
    # Window 0: downlink=256, sensor data [100,100]
    dut.window_downlink_0.value = to_q1616(256)
    dut.sensor_data_0_0.value = to_q1616(100)
    dut.sensor_data_0_1.value = to_q1616(100)
    
    # Window 1: downlink=256, sensor data [100,100]
    dut.window_downlink_1.value = to_q1616(256)
    dut.sensor_data_1_0.value = to_q1616(100)
    dut.sensor_data_1_1.value = to_q1616(100)
    
    # Start computation
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    timeout = 0
    while not dut.done.value and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 200:
        raise TestFailure("Test 1: Timeout - computation did not complete")
    
    # Check result
    if dut.result.value != 1:
        raise TestFailure(f"Test 1: Expected result=1 (possible), got {dut.result.value}")
    print("Test 1: PASSED - Result is possible as expected")
    
    print("
=== Test 2: Impossible case (adapted) ===")
    # Original: 2 windows, 2 queues, 2 sensors, capacities [3,3]
    # Window 1: downlink=1, sensor data [2,2]
    # Window 2: downlink=5, sensor data [2,2]
    # Adapted: 2 windows, 2 queues, 2 sensors, capacities [256,256]
    # Window 1: downlink=100, sensor data [200,200]
    # Window 2: downlink=256, sensor data [200,200]
    # Queue 0 gets 200 + 200 = 400 > 256 (overflow!)
    
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Set parameters
    dut.n_in.value = 2
    dut.q_in.value = 2
    dut.s_in.value = 2
    dut.sensor_queue_map_0.value = 0
    dut.sensor_queue_map_1.value = 1
    
    # Capacities
    dut.queue_capacities_0.value = to_q1616(256)
    dut.queue_capacities_1.value = to_q1616(256)
    
    # Window 0: downlink=100, sensor data [200,200]
    dut.window_downlink_0.value = to_q1616(100)
    dut.sensor_data_0_0.value = to_q1616(200)
    dut.sensor_data_0_1.value = to_q1616(200)
    
    # Window 1: downlink=256, sensor data [200,200]
    dut.window_downlink_1.value = to_q1616(256)
    dut.sensor_data_1_0.value = to_q1616(200)
    dut.sensor_data_1_1.value = to_q1616(200)
    
    # Start
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait
    timeout = 0
    while not dut.done.value and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 200:
        raise TestFailure("Test 2: Timeout")
    
    # Expected: impossible (overflow occurs)
    if dut.result.value != 0:
        raise TestFailure(f"Test 2: Expected result=0 (impossible), got {dut.result.value}")
    print("Test 2: PASSED - Result is impossible as expected")
    
    print("
=== Test 3: Edge case - no data ===")
    # All zeros
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n_in.value = 1
    dut.q_in.value = 1
    dut.s_in.value = 1
    dut.sensor_queue_map_0.value = 0
    dut.queue_capacities_0.value = to_q1616(256)
    dut.window_downlink_0.value = to_q1616(0)
    dut.sensor_data_0_0.value = to_q1616(0)
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 200:
        raise TestFailure("Test 3: Timeout")
    
    if dut.result.value != 1:
        raise TestFailure(f"Test 3: Expected result=1, got {dut.result.value}")
    print("Test 3: PASSED - No data case works")
    
    print("
=== Test 4: Multiple sensors to one queue ===")
    # 2 sensors both to queue 0
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n_in.value = 1
    dut.q_in.value = 1
    dut.s_in.value = 2
    dut.sensor_queue_map_0.value = 0
    dut.sensor_queue_map_1.value = 0
    dut.queue_capacities_0.value = to_q1616(200)
    dut.window_downlink_0.value = to_q1616(150)
    dut.sensor_data_0_0.value = to_q1616(80)
    dut.sensor_data_0_1.value = to_q1616(70)
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 200:
        raise TestFailure("Test 4: Timeout")
    
    # Total 150 data, 150 downlink, should be possible
    if dut.result.value != 1:
        raise TestFailure(f"Test 4: Expected result=1, got {dut.result.value}")
    print("Test 4: PASSED - Multiple sensors to one queue")
    
    print("
=== Test 5: Just fits (capacity check) ===")
    # Queue capacity 100, data 100, downlink 100
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n_in.value = 1
    dut.q_in.value = 1
    dut.s_in.value = 1
    dut.sensor_queue_map_0.value = 0
    dut.queue_capacities_0.value = to_q1616(100)
    dut.window_downlink_0.value = to_q1616(100)
    dut.sensor_data_0_0.value = to_q1616(100)
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 200:
        raise TestFailure("Test 5: Timeout")
    
    if dut.result.value != 1:
        raise TestFailure(f"Test 5: Expected result=1, got {dut.result.value}")
    print("Test 5: PASSED - Just fits capacity")
    
    print("
=== Summary: 5/5 tests passed ===")
    print("All tests completed successfully!")
