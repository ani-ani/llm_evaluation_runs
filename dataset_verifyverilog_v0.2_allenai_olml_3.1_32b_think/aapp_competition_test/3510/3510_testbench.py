import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_game_solver(dut):
    """Test the game solver for specific test case 3"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.start_pos.value = 0
    dut.target_pos.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("Starting Test Case 3 (N=3) Verification")
    
    # Define expected results for Test Case 3
    # a=0, b=1, c=2
    # From a: to a=0, to b=1, to c=-1 (impossible)
    # From b: to a=1, to b=0, to c=-1
    # From c: to a=2, to b=2, to c=0
    
    test_vectors = [
        (0, 0, 0),  # a->a
        (0, 1, 1),  # a->b
        (0, 2, 255), # a->c (impossible)
        (1, 0, 1),  # b->a
        (1, 1, 0),  # b->b
        (1, 2, 255), # b->c
        (2, 0, 2),  # c->a
        (2, 1, 2),  # c->b
        (2, 2, 0)   # c->c
    ]
    
    passed = 0
    total = len(test_vectors)
    
    for start, target, expected in test_vectors:
        dut.start_pos.value = start
        dut.target_pos.value = target
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (with timeout check)
        timeout = 0
        while not dut.done.value and timeout < 100:
            await RisingEdge(dut.clk)
            timeout += 1
            
        if timeout >= 100:
            print(f"FAIL: Start={start}, Target={target} - Timeout")
            continue
            
        # Check result
        res = int(dut.result.value)
        
        # Handle -1 mapping (255 in Verilog)
        if res == 255 and expected == 255:
            print(f"PASS: Start={start}, Target={target} -> -1 (as expected)")
            passed += 1
        elif res == expected:
            print(f"PASS: Start={start}, Target={target} -> {res}")
            passed += 1
        else:
            print(f"FAIL: Start={start}, Target={target} -> Got {res}, Expected {expected}")
            
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total
