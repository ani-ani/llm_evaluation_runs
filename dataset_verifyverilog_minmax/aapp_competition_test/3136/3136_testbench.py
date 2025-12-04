import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_delivery(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset system
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test case 1: Small graph (adapted from sample 1)
    warehouse1 = 1
    warehouse2 = 2
    employees = [7, 3, 4, 0, 0, 0, 0, 0]  # Pad to 8
    clients = [5, 6, 0, 0, 0, 0, 0, 0]     # Pad to 8
    num_deliveries = 2
    adj_matrix = [[0]*8 for _ in range(8)]
    # Populate adjacency matrix (1-based nodes mapped to 0-7 indices)
    edges = [
        (1,3,2), (1,4,1), (1,5,1), (1,6,6),
        (2,3,9), (2,4,2), (2,6,4), (7,6,5)
    ]
    for u,v,d in edges:
        adj_matrix[u-1][v-1] = d
        adj_matrix[v-1][u-1] = d  # undirected

    # Apply inputs
    dut.warehouse1.value = warehouse1-1
    dut.warehouse2.value = warehouse2-1
    for i in range(8):
        dut.employees[i].value = employees[i]-1 if employees[i] else 0
    for i in range(8):
        dut.clients[i].value = clients[i]-1 if clients[i] else 0
    dut.num_deliveries.value = num_deliveries
    for i in range(8):
        for j in range(8):
            dut.adj_matrix[i][j].value = adj_matrix[i][j]

    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for completion (max 20 cycles)
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    assert dut.done.value, "Test 1 timed out"
    assert dut.total_distance.value == 9, f"Test 1 failed: Got {dut.total_distance.value}, expected 9"

    # Test case 2: Simple case (adapted from sample 2)
    warehouse1 = 2-1
    warehouse2 = 2-1
    employees = [1-1] + [0]*7
    clients = [1-1] + [0]*7
    num_deliveries = 1
    adj_matrix[0][1] = adj_matrix[1][0] = 1

    # Apply inputs
    dut.warehouse1.value = warehouse1
    dut.warehouse2.value = warehouse2
    for i in range(8):
        dut.employees[i].value = employees[i]
    for i in range(8):
        dut.clients[i].value = clients[i]
    dut.num_deliveries.value = num_deliveries
    for i in range(8):
        for j in range(8):
            dut.adj_matrix[i][j].value = (1 if (i==0 and j==1) or (i==1 and j==0) else 0)

    # Reset and start again
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    assert dut.done.value, "Test 2 timed out"
    assert dut.total_distance.value == 2, f"Test 2 failed: Got {dut.total_distance.value}, expected 2"

    # Test case 3: Zero distance case (employee at destination)
    warehouse1 = 2-1
    warehouse2 = 1-1
    employees = [1-1, 1-1, 2-1, 2-1, 1-1] + [0]*3
    clients = [2-1, 1-1, 1-1, 2-1, 1-1] + [0]*3
    num_deliveries = 5
    adj_matrix[0][1] = adj_matrix[1][0] = 100

    # Apply
    dut.warehouse1.value = warehouse1
    dut.warehouse2.value = warehouse2
    for i in range(8):
        dut.employees[i].value = employees[i]
    for i in range(8):
        dut.clients[i].value = clients[i]
    dut.num_deliveries.value = num_deliveries
    for i in range(8):
        for j in range(8):
            dut.adj_matrix[i][j].value = (100 if (i==0 and j==1) or (i==1 and j==0) else 0)

    # Reset and start again
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    assert dut.done.value, "Test 3 timed out"
    assert dut.total_distance.value == 0, f"Test 3 failed: Got {dut.total_distance.value}, expected 0"

    dut._log.info("3/3 tests passed")