import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

# Helper to pack instruction
# Type encoding: 0=Compute, 1=Lock, 2=Unlock

def pack_instruction(inst_type, data):
    # inst_type in bits 5:4, data in bits 3:0
    # Actually, let's use full widths as specified in prompt
    return (inst_type << 12) | data

@cocotb.test()
async def test_priority_ceiling_basic(dut):
    """Test basic Priority Ceiling Protocol execution."""
    
    # Start Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.config_valid.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Configuration for Sample Input 1:
    # 3 tasks, 1 resource
    # Task 0: Start 50, Prio 2, Inst: C1 L1 C1 U1 C1
    # Task 1: Start 1, Prio 1, Inst: C1 L1 C100 U1 C1
    # Task 2: Start 70, Prio 3, Inst: C1
    # Resource 0 ceiling: highest task prio locking it = 2 (Task 0) and 1 (Task 1) -> ceiling 2
    
    num_tasks = 3
    num_resources = 1
    
    # Set Parameters (assuming they are parameters, if ports we set them)
    # In Verilog generated, these are parameters usually. 
    # We will assume parameters match the test.
    
    # Load Configuration
    # Task 0
    dut.task_start_time[0].value = 50
    dut.task_priority[0].value = 2
    dut.task_inst_count[0].value = 5
    # Inst 0: C1 -> type 0, data 1
    dut.task_inst_type[0][0].value = 0
    dut.task_inst_data[0][0].value = 1
    # Inst 1: L1 -> type 1, data 1 (resource 1, but prompt says resources 1 to r. Let's use index 0 for resource 1)
    dut.task_inst_type[0][1].value = 1
    dut.task_inst_data[0][1].value = 0
    # Inst 2: C1 -> type 0, data 1
    dut.task_inst_type[0][2].value = 0
    dut.task_inst_data[0][2].value = 1
    # Inst 3: U1 -> type 2, data 0
    dut.task_inst_type[0][3].value = 2
    dut.task_inst_data[0][3].value = 0
    # Inst 4: C1 -> type 0, data 1
    dut.task_inst_type[0][4].value = 0
    dut.task_inst_data[0][4].value = 1
    
    # Task 1
    dut.task_start_time[1].value = 1
    dut.task_priority[1].value = 1
    dut.task_inst_count[1].value = 5
    # C1
    dut.task_inst_type[1][0].value = 0
    dut.task_inst_data[1][0].value = 1
    # L1
    dut.task_inst_type[1][1].value = 1
    dut.task_inst_data[1][1].value = 0
    # C100 -> In test, we usually scale down, but let's try real value or scaled?
    # Prompt said: "Compute times will be capped at 10 cycles".
    # Let's modify the test input to match the "scaled" requirement or assume the design handles up to 100.
    # But to pass the specific sample output 106/107, we need the duration 100.
    # If the design cap is 10, we can't pass the exact sample. 
    # Let's assume the design allows up to 100 for the purpose of this test, or we scale the test down.
    # Let's use C10 for the test to verify logic quickly, and explain.
    # Actually, let's stick to the prompt's advice: "Scale inputs down dramatically".
    # I will modify the test case to use C10 instead of C100 to fit the 'MAX_COMPUTE=10' parameter.
    # Expected Output change: Task 1 takes 10 instead of 100. Total shift 90.
    # Original: T0 finishes 106, T1 107, T2 71.
    # Scaled: T1 computes 10 cycles. 
    # T0 starts 50, T1 starts 1.
    # T1 runs 1 (1-50). C1, L1. T0 arrives 50. T0 has higher prio (2) than T1 (1) but T1 owns L1.
    # Ceiling of L1 is 2 (Task 0's prio). 
    # T0 requests L1. Is blocked? Condition: Ceiling >= T0 prio (2 >= 2). Yes. Blocked by T1.
    # So T1 continues. T1 runs C10 (10 cycles). Time becomes 1 + 1 + 10 = 12.
    # T1 Unlocks. Time 12.
    # T0 runs. C1 (time 13), L1 (time 13), C1 (time 14), U1 (time 14), C1 (time 15).
    # T0 finishes at 15.
    # T2 starts 70. Runs C1. Finishes 71.
    # Wait, T1 continues AFTER T0?
    # T1 was blocked T0, T1 has prio 1. T0 has prio 2. 
    # When T0 arrives, T1 is running. T0 tries to lock. T1 owns resource.
    # Priority Inheritance: T1 inherits T0's priority (2).
    # So T1 (now prio 2) vs T0 (prio 2). Who runs? "There will never be a tie".
    # Usually, the current owner runs. Or the one with higher base priority? 
    # The problem says: "Execute ... with the highest current priority". Tie breaker not specified but "never a tie".
    # If we use base priority as tie breaker implicitly: T0 (base 2), T1 (base 1). T0 runs? No, T1 is already running.
    # The problem says: "determine... which are blocked".
    # T0 is blocked. T1 is running (inherits T0's priority).
    # So T1 runs compute. T0 waits.
    # T1 finishes compute, Unlocks. T1 finishes? No, T1 has C1 after U1.
    # T1 unlocks. T0 can now lock. T0 runs C1, L1, C1, U1, C1. 
    # T1 is now ready again (needs C1). Prio 1.
    # T0 Prio 2. T0 runs to completion.
    # Then T1 runs C1. T1 finishes.
    # Then T2 runs.
    # Wait, T2 starts 70. If T0/T1 finish < 70, fine. If > 70, T2 (Prio 3) runs first.
    # With scaled C10:
    # 0-1: Idle
    # 1: T1 C1
    # 2-11: T1 C10 (10 cycles). Time=12 at end.
    # 12: T1 U1 (inst index 3).
    # T0 is active (50 > 12? No, 50 > 12. T0 not started yet). 
    # So T1 runs U1. T1 then has C1 left. 
    # 12: T1 U1 (clock not inc). Next inst C1.
    # T0 not started. T1 runs C1. Time 13. T1 done.
    # 50: T0 arrives. Runs C1 (51), L1 (51), C1 (52), U1 (52), C1 (53). Done 53.
    # 70: T2 arrives. Runs C1 (71). Done.
    # Output: 53, 13, 71. (Wait, 13 is wrong, 12 end of compute, 13 end of C1).
    # Let's look at Sample 1 logic carefully.
    # Sample 1 Output: 106, 107, 71.
    # T1 starts 1. C1 (1->2). L1 (2). C100 (2->102). U1 (102). C1 (102->103). Done 103? Why 107?
    # Ah, T0 starts 50. T0 has Prio 2. T1 has Prio 1.
    # At T=2, T1 owns resource. T0 arrives T=50. T0 needs L1. 
    # Blocked? Ceiling of L1 is 2 (T0's prio). Ceiling >= T0 prio (2 >= 2). Yes. Blocked.
    # So T1 continues (inherits Prio 2). Runs C100. 
    # Clock goes 2 to 102 (100 cycles).
    # T1 Unlocks (102). 
    # T0 can run. T0 C1 (103), L1 (103), C1 (104), U1 (104), C1 (105). Done 105? Why 106?
    # Ah, T0 arrives at 50. At T=50, T1 is in C100 (at cycle 50).
    # T0 wants to run. T1 runs because it's the only non-blocked task (T0 blocked).
    # T1 continues until Unlock.
    # After Unlock, T0 runs.
    # T0 finishes at 105. 
    # Then T1 runs C1 (106). Done 106? Output says T1 is 107.
    # T2 is 71. 
    # Let's re-read Sample Output: 106, 107, 71.
    # Line 1 is Task 0? Input order.
    # Input: Line 1: Task 0 (Start 50, Prio 2). Line 2: Task 1 (Start 1, Prio 1). Line 3: Task 2 (Start 70, Prio 3).
    # Output 106 -> Task 0. Output 107 -> Task 1. Output 71 -> Task 2.
    # Okay, so Task 0 finishes 106, Task 1 finishes 107.
    # T1 runs 1->2 (C1). 2->102 (C100). 102 (U1). 
    # T0 runs 102->103 (C1), 103 (L1), 103->104 (C1), 104 (U1), 104->105 (C1). Done 105? Why 106?
    # Maybe clock increments happen *after* execution?
    # "If compute instruction was executed, increment the processor clock by one microsecond."
    # T1 C100: at T=2, executes. End of cycle clock=3? Or duration?
    # "compute for one microsecond" usually means takes 1 unit of time.
    # "C100 indicates a sequence of 100 compute instructions." So 100 cycles.
    # T1 at 1: C1 (Clock 2).
    # T1 at 2: L1 (Clock 2).
    # T1 at 2: Start C100. 
    # Step 3: "If a compute instruction was executed, increment the processor clock by one microsecond."
    # So 100 increments. 
    # Clock starts at 2. 
    # Cycle 1: Exec C100 (part 1). Clock 3.
    # Cycle 99: Exec C100 (part 99). Clock 101.
    # Cycle 100: Exec C100 (part 100). Clock 102.
    # T1 finishes C100 at Clock 102.
    # T1 U1 (Clock 102).
    # T0 C1 (Clock 103).
    # T0 L1 (Clock 103).
    # T0 C1 (Clock 104).
    # T0 U1 (Clock 104).
    # T0 C1 (Clock 105).
    # Done 105. Why 106?
    # Let's check T2. T2 Start 70. T2 Prio 3.
    # T2 C1. If T2 runs, it takes 1 cycle. 
    # If T1 is running C100 (2-102) and T0 is blocked. T2 arrives 70.
    # T2 is not blocked. T2 Prio 3. T1 is running but blocked? T1 is running, T0 blocked. T1 has prio 2 (inherited).
    # T2 has prio 3. 
    # So at 70, T2 should preempt T1!
    # T1 runs 2->70. 68 cycles. T1 C100 left: 32 cycles.
    # Clock 70: T2 runs C1. Clock 71. T2 done.
    # Then T1 continues C100. 32 cycles. Clock 71 + 32 = 103.
    # T1 U1 (103). T0 runs.
    # T0 C1 (104). L1 (104). C1 (105). U1 (105). C1 (106). T0 done 106.
    # T1 runs C1 (107). T1 done 107.
    # Okay, this matches sample output.
    # So the scheduler must check for higher priority tasks arriving *during* a compute loop.

    # So in the test, we must have the logic to handle this.
    # For the testbench, we use the scaled C100 (C10 for simulation speed if needed, but let's try to match prompt's "Max Compute 10" limitation).
    # If I use C10, the logic is:
    # T1: 1->2 (C1), 2->12 (C10). 
    # T2 arrives 70 -> > 12, so T2 runs at 70. 
    # T2 finishes 71.
    # T1 finishes C10 at 12. T1 U1 (12). T0 runs (starts 50, but 50 > 12).
    # Wait, if T1 finishes at 12, and T0 starts 50, T1 has U1 and C1.
    # T1 U1 (12). T1 C1 (13). T1 done 13.
    # 50: T0 runs. C1 (51), L1 (51), C1 (52), U1 (52), C1 (53). Done 53.
    # Output: 53, 13, 71.
    # This is a valid test case for the logic, just scaled time.
    
    # Let's use the scaled test case for the testbench to respect the "Max Compute 10" constraint.
    
    # Task 0: C1, L1, C1, U1, C1
    # Task 1: C1, L1, C10, U1, C1
    # Task 2: C1
    # Resource 0 ceiling: 2 (highest of task 0 and 1)
    
    dut.task_inst_type[1][2].value = 0
    dut.task_inst_data[1][2].value = 10 # C10
    
    dut.task_inst_type[1][3].value = 2 # U1
    dut.task_inst_data[1][3].value = 0
    
    dut.task_inst_type[1][4].value = 0 # C1
    dut.task_inst_data[1][4].value = 1
    
    # Task 2
    dut.task_start_time[2].value = 70
    dut.task_priority[2].value = 3
    dut.task_inst_count[2].value = 1
    dut.task_inst_type[2][0].value = 0
    dut.task_inst_data[2][0].value = 1
    
    # Resource Ceiling
    dut.resource_ceiling[0].value = 2
    
    dut.config_valid.value = 1
    await RisingEdge(dut.clk)
    dut.config_valid.value = 0
    
    # Start simulation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Run simulation
    # Expected duration: 
    # T1 runs 0-1 (C1), 1-2 (L1), 2-12 (C10), 12 (U1), 12-13 (C1). Finish 13.
    # T2 starts 70. 
    # T0 starts 50.
    # T0 needs L1 (owned by T1 until 12). T0 blocked until 12.
    # T0 runs 12->13 (Wait, T1 runs until 13). 
    # Actually T1 runs until 12 (C10 done), U1 at 12, C1 at 13. 
    # T0 cannot run L1 until T1 U1.
    # At 12, T1 U1. T0 can run. 
    # T0 C1 (13), L1 (13), C1 (14), U1 (14), C1 (15). Done 15.
    # T2 arrives 70. T2 Prio 3. T1 Prio 1 (base). T0 Prio 2.
    # T2 should run immediately at 70 if idle.
    # If T1/T0 are running past 70, T2 preempts.
    # T1 finishes 13 (< 70). T0 finishes 15 (< 70).
    # So T2 runs at 70. C1 -> 71.
    
    max_cycles = 200
    for _ in range(max_cycles):
        if dut.result_valid.value == 1:
            break
        await RisingEdge(dut.clk)
    
    # Check results
    # Expected: Task 0 = 15, Task 1 = 13, Task 2 = 71
    
    if dut.result_valid.value != 1:
        raise TestFailure(f"Simulation did not finish in {max_cycles} cycles")
        
    t0_time = int(dut.task_completion_time[0].value)
    t1_time = int(dut.task_completion_time[1].value)
    t2_time = int(dut.task_completion_time[2].value)
    
    print(f"Task 0 completion: {t0_time} (Expected 15)")
    print(f"Task 1 completion: {t1_time} (Expected 13)")
    print(f"Task 2 completion: {t2_time} (Expected 71)")
    
    # Allow small error for sim ticks
    assert t1_time == 13, f"Task 1 failed: {t1_time}"
    assert t0_time == 15, f"Task 0 failed: {t0_time}"
    assert t2_time == 71, f"Task 2 failed: {t2_time}"

@cocotb.test()
async def test_priority_ceiling_preemption(dut):
    """Test high priority task preemption of low priority task inheriting priority."""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.config_valid.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Setup 2 tasks, 1 resource
    # Task 0: Start 1, Prio 1 (Highest), Inst: C1, L1, C5, U1
    # Task 1: Start 5, Prio 2, Inst: L1, C5, U1
    # Ceiling of L1: 1 (Task 0 locks it)
    
    # Task 0
    dut.task_start_time[0].value = 1
    dut.task_priority[0].value = 1
    dut.task_inst_count[0].value = 3
    dut.task_inst_type[0][0].value = 0; dut.task_inst_data[0][0].value = 1
    dut.task_inst_type[0][1].value = 1; dut.task_inst_data[0][1].value = 0
    dut.task_inst_type[0][2].value = 0; dut.task_inst_data[0][2].value = 5
    dut.task_inst_type[0][3].value = 2; dut.task_inst_data[0][3].value = 0
    
    # Task 1
    dut.task_start_time[1].value = 5
    dut.task_priority[1].value = 2
    dut.task_inst_count[1].value = 3
    dut.task_inst_type[1][0].value = 1; dut.task_inst_data[1][0].value = 0
    dut.task_inst_type[1][1].value = 0; dut.task_inst_data[1][1].value = 5
    dut.task_inst_type[1][2].value = 2; dut.task_inst_data[1][2].value = 0
    
    dut.resource_ceiling[0].value = 1
    
    dut.config_valid.value = 1
    await RisingEdge(dut.clk)
    dut.config_valid.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    max_cycles = 100
    for _ in range(max_cycles):
        if dut.result_valid.value == 1:
            break
        await RisingEdge(dut.clk)
        
    if dut.result_valid.value != 1:
        raise TestFailure("Simulation timed out")
        
    # Logic:
    # T0 Start 1. C1 (Clock 2). L1 (Clock 2). T0 owns L1.
    # T0 C5 (2->7).
    # T1 Start 5. T1 needs L1 (owned by T0). T1 blocked.
    # T0 continues C5. T0 finishes C5 at 7.
    # T0 U1 (7). T0 done (or continues if more inst).
    # T1 runs L1 (7). T1 C5 (7->12). T1 U1 (12). T1 done.
    
    t0_time = int(dut.task_completion_time[0].value)
    t1_time = int(dut.task_completion_time[1].value)
    
    print(f"Task 0: {t0_time} (Expected 7)")
    print(f"Task 1: {t1_time} (Expected 12)")
    
    assert t0_time == 7, f"Task 0 failed: {t0_time}"
    assert t1_time == 12, f"Task 1 failed: {t1_time}"
