import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_droplet(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test case from first sample input (scaled down)
    droplets = [
        (1, 8),  # Expected: 4
        (2, 3),  # Expected: 1
        (2, 8),  # Expected: 4
        (5, 8),  # Expected: 6
        (5, 9)   # Expected: 0
    ]
    sensors = [
        (3, 6, 6),
        (1, 7, 4),
        (1, 3, 1)
    ]

    # Initialize inputs
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(8):
        dut.droplet_x[i].value = 0
        dut.droplet_y[i].value = 0
    for i in range(4):
        dut.sensor_x1[i].value = 0
        dut.sensor_x2[i].value = 0
        dut.sensor_y[i].value = 0
    dut.droplet_count.value = 5
    dut.sensor_count.value = 3

    # Reset - wait 2 cycles
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Load droplet data
    for i, (x, y) in enumerate(droplets):
        dut.droplet_x[i].value = x
        dut.droplet_y[i].value = y
    # Load sensor data
    for i, (x1, x2, y) in enumerate(sensors):
        dut.sensor_x1[i].value = x1
        dut.sensor_x2[i].value = x2
        dut.sensor_y[i].value = y

    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for computation (8 cycles total)
    for _ in range(8):
        await RisingEdge(dut.clk)

    assert dut.done.value == 1, "Done signal not asserted"
    expected = [4, 1, 4, 6, 0]
    passed = 0
    for i in range(5):
        if dut.result[i].value == expected[i]:
            passed += 1
        else:
            dut._log.error(f"Droplet {i}: Expected {expected[i]}, got {dut.result[i].value}")
    dut._log.info(f"{passed}/5 tests passed")