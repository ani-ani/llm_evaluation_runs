import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_coloring_counter(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.N.value = 0
    dut.M_i.value = 0
    dut.l_i.value = 0
    dut.r_i.value = 0
    dut.x_i.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("Starting Tests...")
    
    # Test Case 1: N=3, M=1, l=1, r=3, x=3 (All 3 colors in interval [1,3])
    # Expected: 6
    dut.N.value = 3
    dut.M_i.value = 1
    dut.l_i.value = 1
    dut.r_i.value = 3
    dut.x_i.value = 3
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (N=3, M=1 -> ~27 cycles logic + overhead)
    timeout = 0
    while dut.done.value == 0 and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
        
    assert dut.done.value == 1, "Test 1: Module did not finish"
    assert dut.result.value == 6, f"Test 1 Failed: Expected 6, got {dut.result.value}"
    print(f"Test 1 Passed: Result={dut.result.value}")
    
    # Test Case 2: N=4, M=2
    # Condition 1: [1,3], 1 color
    # Condition 2: [2,4], 2 colors
    # Expected: 6
    await Timer(50, units='ns')
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.N.value = 4
    # We need to feed M conditions. The interface seems to feed one per cycle or via parallel inputs.
    # Based on prompt interface, we have l_i, r_i, x_i. Assume we feed M_i conditions sequentially if M_i > 0?
    # Or the module has internal storage for max M=16.
    # Let's assume we load them sequentially before the start signal or via a load signal.
    # Prompt says "During SETUP, load conditions". We need a load signal not defined. 
    # I will assume that for this test, we can simply set the inputs and start, and maybe use M_i as a load counter.
    # Actually, to keep it simple, let's just verify the module structure logic.
    # Re-reading prompt: "input [7:0] M_i". 
    # Let's modify the test to simply verify the start/finish sequence for a known input.
    # If M_i is just an input count, we likely need a valid signal to load.
    # Let's assume the interface has a `cond_valid` signal for loading. 
    # *Correction*: The prompt interface is fixed. 
    # Let's assume that for simplicity, `M_i` is the number of conditions to load, and we assert `start`.
    # The module handles the rest.
    # However, without a defined loading mechanism for multiple conditions in the prompt, 
    # I will test Case 1 only (M=1) to ensure the core logic works, as M>1 requires specific loading protocol.
    
    # Let's try a simpler test case 2: N=1, M=1, l=1, r=1, x=1
    # All 3 colors (R, G, B). Only 1 square. x=1 means only 1 color in [1,1].
    # Valid colorings: R, G, B (each has exactly 1 color). So 3.
    await RisingEdge(dut.clk)
    dut.N.value = 1
    dut.M_i.value = 1
    dut.l_i.value = 1
    dut.r_i.value = 1
    dut.x_i.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while dut.done.value == 0 and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
        
    assert dut.done.value == 1
    assert dut.result.value == 3, f"Test 2 Failed: Expected 3, got {dut.result.value}"
    print(f"Test 2 Passed: Result={dut.result.value}")
    
    # Test Case 3: N=2, M=1, l=1, r=2, x=1
    # Square 1 and 2. Must have exactly 1 color total in [1,2].
    # Valid: (R,R), (G,G), (B,B). Count = 3.
    await RisingEdge(dut.clk)
    dut.N.value = 2
    dut.M_i.value = 1
    dut.l_i.value = 1
    dut.r_i.value = 2
    dut.x_i.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while dut.done.value == 0 and timeout < 150:
        await RisingEdge(dut.clk)
        timeout += 1
        
    assert dut.done.value == 1
    assert dut.result.value == 3, f"Test 3 Failed: Expected 3, got {dut.result.value}"
    print(f"Test 3 Passed: Result={dut.result.value}")
    
    # Test Case 4: N=2, M=1, l=1, r=2, x=3
    # Need 3 colors in 2 squares. Impossible. Count = 0.
    await RisingEdge(dut.clk)
    dut.N.value = 2
    dut.M_i.value = 1
    dut.l_i.value = 1
    dut.r_i.value = 2
    dut.x_i.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while dut.done.value == 0 and timeout < 150:
        await RisingEdge(dut.clk)
        timeout += 1
        
    assert dut.done.value == 1
    assert dut.result.value == 0, f"Test 4 Failed: Expected 0, got {dut.result.value}"
    print(f"Test 4 Passed: Result={dut.result.value}")
    
    print("All tests passed!")
