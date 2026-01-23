import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_boomerang_solver(dut):
    """Test the boomerang solver with various inputs"""
    
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.a_in.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases: list of (name, input_list, expected_targets, expected_error)
    # input_list: [a1, a2, a3, a4] (column 1 to 4)
    # expected_targets: list of (r, c)
    
    # Case 1: [1, 1, 1, 1] - 4 single hits
    test_cases = [
        ([1, 1, 1, 1], [(1,1), (2,2), (3,3), (4,4)], False),
        # Case 2: [2, 0, 1, 1] - 2 needs 1, 1 needs nothing
        # Processed right-to-left: 1, 1, 0, 2
        # Col 4 (a=1): Output (4,4), Pending=[4]
        # Col 3 (a=1): Output (3,3), Pending=[4,3]
        # Col 2 (a=0): Nothing
        # Col 1 (a=2): Needs pending, takes 3. Output (3,1). Two_stack=[3]. Pending=[4]
        ([2, 0, 1, 1], [(4,4), (3,3), (3,1)], False),
        # Case 3: [3, 2, 1, 1] - 3 needs 2, 2 needs 1
        # Col 4 (a=1): Output (4,4), Pending=[4]
        # Col 3 (a=2): Needs pending, takes 4. Output (4,3). Two_stack=[4]. Pending=[]
        # Col 2 (a=3): Needs from Two_stack (takes 4). Output (2,2) and (2,4). Two_stack=[2]. Pending=[]
        # Col 1 (a=3): Needs from Two_stack (takes 2). Output (1,1) and (1,2). Two_stack=[1]. Pending=[]
        ([3, 2, 1, 1], [(4,4), (4,3), (2,2), (2,4), (1,1), (1,2)], False),
        # Case 4: [3, 1, 0, 0] - 3 needs 2, but only 1 available eventually -> Error
        ([3, 1, 0, 0], [], True)
    ]
    
    for inputs, expected_targets, should_error in test_cases:
        dut._log.info(f"Running test: {inputs}")
        
        # Prepare inputs (process left to right, but module processes right to left)
        # Our inputs list is [a1, a2, a3, a4] for columns 1..4
        # We feed a4, a3, a2, a1 to the module
        
        # Start sequence
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        collected_targets = []
        error_occurred = False
        
        # We need to drive inputs and collect outputs for 4 cycles
        # The module might output 0, 1 or 2 targets per cycle
        
        # Feed inputs: reversed order
        feed_queue = list(reversed(inputs))
        
        # Main processing loop (4 cycles)
        for cycle in range(4):
            # Drive input
            if cycle < len(feed_queue):
                dut.a_in.value = feed_queue[cycle]
            else:
                dut.a_in.value = 0
            
            await RisingEdge(dut.clk)
            
            # Check outputs for this cycle (might be multiple valid pulses, but we check after clk edge)
            # In cocotb, we check the value on the signal
            if dut.valid.value:
                collected_targets.append((int(dut.target_r.value), int(dut.target_c.value)))
            
            if dut.error.value:
                error_occurred = True
        
        # Check Done
        if not dut.done.value:
            raise TestFailure(f"Done not high after 4 cycles for test {inputs}")
            
        # Verify
        if should_error:
            if not error_occurred:
                raise TestFailure(f"Expected error for inputs {inputs}, but no error occurred. Collected: {collected_targets}")
        else:
            if error_occurred:
                raise TestFailure(f"Unexpected error for inputs {inputs}")
            
            # Check targets
            # Sort both lists for comparison as order might vary slightly in output sequence
            # But usually they appear in column order
            if sorted(collected_targets) != sorted(expected_targets):
                raise TestFailure(f"Mismatch for {inputs}. Exp: {expected_targets}, Got: {collected_targets}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await Timer(10, units='ns')
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    dut._log.info("All tests passed!")
