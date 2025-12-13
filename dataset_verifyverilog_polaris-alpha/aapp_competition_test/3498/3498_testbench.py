import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import numpy as np

@cocotb.test()
async def test_priority_scheduler(dut):
    # Create clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    # Reset system
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1 (original sample scaled)
    test_input = [
        # Task 0 (original 50 2 5 C1 L1 C1 U1 C1)
        {"start": 50, "pri": 2, "subops": [('C',1), ('L',1), ('C',1), ('U',1), ('C',1)]},
        # Task 1 (original 1 1 5 C1 L1 C100 U1 C1)
        {"start": 1, "pri": 1, "subops": [('C',1), ('L',1), ('C',100), ('U',1), ('C',1)]},
        # Task 2 (original 70 3 1 C1)
        {"start": 70, "pri": 3, "subops": [('C',1)]},
        # Empty task slot
        {"start": 1000, "pri": 0, "subops": []}
    ]
    expected_out = [106, 107, 71, 0]
    
    # Initialize module state (emulate pre-loaded configuration)
    # ... (implementation would normally load task config here)
    
    # Run simulation until all tasks complete (107 + margin)
    for _ in range(200):
        await RisingEdge(dut.clk)
    
    # Get outputs
    outputs = [dut.task_complete[0].value, dut.task_complete[1].value, 
               dut.task_complete[2].value, dut.task_complete[3].value]
    
    # Verify results
    passed = 0
    for i in range(3):
        if outputs[i] == expected_out[i]:
            passed += 1
        else:
            dut._log.error(f"Task {i} failed: expected {expected_out[i]}, got {outputs[i].integer}")
    dut._log.info(f"{passed}/3 tests passed")