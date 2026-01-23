import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_curfew_enforcement(dut):
    """Test the Curfew Enforcement module"""
    
    # Parameters matching the Verilog module
    N = 64
    B = 16
    
    # Clock generation
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.a_in.value = 0
    dut.d_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("--- Starting Test Sequence ---")
    
    # Test case 1: Corresponds to "5 1 1
1 0 0 0 4"
    # Scaled to N=64 (effectively first 5 rooms matter)
    # d=1, B=16. Expect output 1.
    # Note: With B=16, we need more students to fill rooms.
    # Original: 1 0 0 0 4. Capacity 1. Total 5.
    # Scaled: Let's use d=1, B=1.
    # But module uses B=16. Let's manually check logic with B=16.
    # If B=16, we need 16 students per room. We have 5 total.
    # Result would be high complaints (everyone fails).
    # Let's adapt test to match module parameters or verify logic.
    # 
    # Let's verify the algorithm logic:
    # n=5, d=1, b=1. a=[1,0,0,0,4]
    # i=1: left_limit=1, right_limit=3. Left=1, Right=4. min=1. i=1. complaints = 1 - 1/1 = 0.
    # i=2: left_limit=2, right_limit=2. Left=1, Right=4. min=1. i=2. complaints = 2 - 1/1 = 1.
    # Result = 1.
    # 
    # For module with B=16:
    # We need to scale inputs. Let's set B=1 in a new module run or verify the formula.
    # Actually, let's stick to B=16 in the module but use scaled inputs in the test.
    # Let's define a test case that works with B=16.
    # 
    # Custom Test Case:
    # n=5. B=16. Need 80 students total.
    # a = [40, 0, 0, 0, 40]
    # d = 1. 
    # Step 1 (i=1): 
    #   Left room 0: 40 students. Right room 4: 40 students.
    #   Left limit index = 1*1 = 1. Prefix[1] = 40.
    #   Right limit index = 5 - 1 - 1*1 = 3. Prefix[3] = 40.
    #   Total = 80. Right students = 80 - 40 = 40.
    #   Available = min(40, 40) = 40.
    #   Filled = 40 / 16 = 2. Target rooms = 1.
    #   Complaints = 1 - 2 = 0 (but negative means 0? Or wait.
    #   If we fill 2 rooms when we only need 1, we are good. Complaints = 0.
    #   
    # Step 2 (i=2):
    #   Left limit index = 2*1 = 2. Prefix[2] = 40.
    #   Right limit index = 5 - 1 - 2*1 = 2. Prefix[2] = 40.
    #   Right students = 80 - 40 = 40.
    #   Available = min(40, 40) = 40.
    #   Filled = 40 / 16 = 2. Target rooms = 2.
    #   Complaints = 2 - 2 = 0.
    #   
    # Max complaints = 0.
    # So this test case should output 0.
    
    # Let's run a test case that outputs 1 or more to verify calculation.
    # Try: n=5, B=16, a=[16, 0, 0, 0, 16], d=1.
    # Total = 32. 
    # i=1: Left=16, Right=16. Avail=16. Filled=1. Target 1. Comp=0.
    # i=2: Left=16, Right=16. Avail=16. Filled=1. Target 2. Comp=1.
    # Result = 1. 
    
    test_cases = [
        # n=5, d=1, B=16
        # Input: [16, 0, 0, 0, 16] -> Expect 1
        {'d': 1, 'a': [16, 0, 0, 0, 16] + [0]*(N-5), 'expected': 1},
        # Input: [32, 0, 0, 0, 32] -> Expect 0
        {'d': 1, 'a': [32, 0, 0, 0, 32] + [0]*(N-5), 'expected': 0},
        # Input: [0, 0, 0, 0, 32] (all on right) -> d=1
        # i=1: Left=0, Right=32. Avail=0. Filled=0. Target 1. Comp=1.
        # i=2: Left=0, Right=32. Avail=0. Filled=0. Target 2. Comp=2.
        # Result = 2.
        {'d': 1, 'a': [0, 0, 0, 0, 32] + [0]*(N-5), 'expected': 2},
    ]

    passed = 0
    total = len(test_cases)
    
    for tc in test_cases:
        print(f"
Running test case: d={tc['d']}, expected={tc['expected']}")
        
        # 1. Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # 2. Load phase - Feed inputs
        # Module requests address 0, then 1, ... up to N-1
        for i in range(N):
            # Wait for request (req_en should be high)
            # In IDLE/LOAD state, module asserts req_en
            # We need to wait for dut.addr_out to match i, or just keep feeding if it's sequential
            # The module described has `addr_out` output for requesting.
            # But in the prompt I said "valid_in" and "a_in" are inputs.
            # The module logic: Request address X, receive data.
            # To make it testable, the testbench should monitor `addr_out` and provide data.
            
            # Wait for req_en (and implicitly addr_out update)
            # Since it's a simple sequence, we can just wait a few cycles or check addr_out
            # Let's assume the module asserts req_en in LOAD state.
            
            timeout = 0
            while not dut.req_en.value and timeout < 20:
                await RisingEdge(dut.clk)
                timeout += 1
            
            if timeout >= 20:
                print("Error: Timeout waiting for request")
                break
                
            # Provide data
            dut.a_in.value = int(tc['a'][i])
            dut.valid_in.value = 1
            # Also provide d_in if needed (input once)
            dut.d_in.value = tc['d']
            
            await RisingEdge(dut.clk)
            dut.valid_in.value = 0
            
        print("Data loading complete.")
        
        # 3. Wait for computation
        timeout = 0
        while not dut.done.value and timeout < 100:
            await RisingEdge(dut.clk)
            timeout += 1
            
        if timeout >= 100:
            print("Error: Timeout waiting for done")
            break
            
        # 4. Check result
        actual = int(dut.result.value)
        expected = tc['expected']
        
        if actual == expected:
            print(f"PASS: Result {actual} matches expected {expected}")
            passed += 1
        else:
            print(f"FAIL: Result {actual} does not match expected {expected}")
            
        # Reset between tests if necessary (or just start new sequence)
        # The module resets on start, so we are good.
        
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed} out of {total} tests passed"