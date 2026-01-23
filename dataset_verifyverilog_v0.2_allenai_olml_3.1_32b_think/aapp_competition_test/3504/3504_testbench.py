import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_antimatter_rain(dut):
    # Initialize clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Sample Input
    # D=5, S=3
    # Drops: (1,8), (2,3), (2,8), (5,8), (5,9)
    # Sensors: (3,6,6), (1,7,4), (1,3,1)
    # Expected: 4, 1, 4, 6, 0
    
    dut.num_droplets.value = 5
    dut.num_sensors.value = 3
    
    # Droplets (x,y)
    dut.drop_x[0].value = 1; dut.drop_y[0].value = 8
    dut.drop_x[1].value = 2; dut.drop_y[1].value = 3
    dut.drop_x[2].value = 2; dut.drop_y[2].value = 8
    dut.drop_x[3].value = 5; dut.drop_y[3].value = 8
    dut.drop_x[4].value = 5; dut.drop_y[4].value = 9
    # Fill rest with 0
    for i in range(5, 8):
        dut.drop_x[i].value = 0
        dut.drop_y[i].value = 0
    
    # Sensors (x1, x2, y)
    dut.sensor_x1[0].value = 3; dut.sensor_x2[0].value = 6; dut.sensor_y[0].value = 6
    dut.sensor_x1[1].value = 1; dut.sensor_x2[1].value = 7; dut.sensor_y[1].value = 4
    dut.sensor_x1[2].value = 1; dut.sensor_x2[2].value = 3; dut.sensor_y[2].value = 1
    # Fill rest with 0
    for i in range(3, 8):
        dut.sensor_x1[i].value = 0
        dut.sensor_x2[i].value = 0
        dut.sensor_y[i].value = 0
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 100
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Timeout waiting for done")
    
    # Check results
    expected = [4, 1, 4, 6, 0]
    for i in range(5):
        actual = int(dut.result[i].value)
        if actual != expected[i]:
            raise TestFailure(f"Droplet {i}: Expected {expected[i]}, got {actual}")
    
    print("Test 1 Passed: 5/5 results correct")
    
    # Test Case 2: Second Sample
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # D=6, S=3
    # Drops: (1,2), (4,8), (5,10), (6,10), (7,10), (8,10)
    # Sensors: (1,1,1), (3,4,3), (5,7,9)
    # Expected: 1, 3, 9, 9, 9, 0
    
    dut.num_droplets.value = 6
    dut.num_sensors.value = 3
    
    dut.drop_x[0].value = 1; dut.drop_y[0].value = 2
    dut.drop_x[1].value = 4; dut.drop_y[1].value = 8
    dut.drop_x[2].value = 5; dut.drop_y[2].value = 10
    dut.drop_x[3].value = 6; dut.drop_y[3].value = 10
    dut.drop_x[4].value = 7; dut.drop_y[4].value = 10
    dut.drop_x[5].value = 8; dut.drop_y[5].value = 10
    for i in range(6, 8):
        dut.drop_x[i].value = 0
        dut.drop_y[i].value = 0
        
    dut.sensor_x1[0].value = 1; dut.sensor_x2[0].value = 1; dut.sensor_y[0].value = 1
    dut.sensor_x1[1].value = 3; dut.sensor_x2[1].value = 4; dut.sensor_y[1].value = 3
    dut.sensor_x1[2].value = 5; dut.sensor_x2[2].value = 7; dut.sensor_y[2].value = 9
    for i in range(3, 8):
        dut.sensor_x1[i].value = 0
        dut.sensor_x2[i].value = 0
        dut.sensor_y[i].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 100
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Timeout waiting for done")
        
    expected = [1, 3, 9, 9, 9, 0]
    for i in range(6):
        actual = int(dut.result[i].value)
        if actual != expected[i]:
            raise TestFailure(f"Droplet {i}: Expected {expected[i]}, got {actual}")
            
    print("Test 2 Passed: 6/6 results correct")
    print("All tests passed!")
