import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

def get_light_state(t, a, b, initial):
    """Helper to compute light state in Python"""
    if t < b:
        return initial
    # Count how many toggles happen at or before time t
    # Toggles at times: b, b+a, b+2a, ...
    if (t - b) % a == 0:
        # This is a toggle point. 
        # The number of steps from b to t inclusive is ((t-b)//a) + 1
        num_toggles = ((t - b) // a) + 1
        return initial ^ (num_toggles % 2)
    return initial

@cocotb.test()
async def test_lights_controller(dut):
    """Test the lights controller module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.initial_states.value = 0
    for i in range(16):
        dut.a[i].value = 0
        dut.b[i].value = 0
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Example 1 (Adapted)
    # Original: 3 lights, params (3,3), (3,2), (3,1), states 101
    # We have 16 lights, so we use the first 3 and leave others off
    # Expected output: 2
    
    initial = 0b0000000000000101 # Lights 0 and 2 on
    a_vals = [3, 3, 3] + [1] * 13
    b_vals = [3, 2, 1] + [0] * 13
    
    dut.initial_states.value = initial
    for i in range(16):
        dut.a[i].value = a_vals[i]
        dut.b[i].value = b_vals[i]
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 2000
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    # Calculate expected value manually
    expected_max = 0
    for t in range(64):
        on_count = 0
        for i in range(3):
            state = get_light_state(t, a_vals[i], b_vals[i], (initial >> i) & 1)
            if state == 1:
                on_count += 1
        if on_count > expected_max:
            expected_max = on_count
            
    dut._log.info(f"Test 1: Result {int(dut.max_lights.value)}, Expected {expected_max}")
    assert int(dut.max_lights.value) == expected_max, f"Mismatch: {int(dut.max_lights.value)} != {expected_max}"
    
    # Wait for next cycle to reset
    await RisingEdge(dut.clk)
    
    # Test Case 2: Example 2 (Adapted)
    # Original: 4 lights, all on initially, params varied
    # Expected output: 4
    
    initial = 0b0000000000001111 # First 4 lights on
    a_vals = [3, 5, 3, 3] + [1] * 12
    b_vals = [4, 2, 1, 2] + [0] * 12
    
    dut.initial_states.value = initial
    for i in range(16):
        dut.a[i].value = a_vals[i]
        dut.b[i].value = b_vals[i]
        
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 2000
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    expected_max = 0
    for t in range(64):
        on_count = 0
        for i in range(4):
            state = get_light_state(t, a_vals[i], b_vals[i], (initial >> i) & 1)
            if state == 1:
                on_count += 1
        if on_count > expected_max:
            expected_max = on_count
            
    dut._log.info(f"Test 2: Result {int(dut.max_lights.value)}, Expected {expected_max}")
    assert int(dut.max_lights.value) == expected_max, f"Mismatch: {int(dut.max_lights.value)} != {expected_max}"
    
    # Test Case 3: Example 3 (Adapted)
    # Original: 6 lights, states 011100
    # Expected output: 6
    
    initial = 0b0000000000111000 # Bits 3,4,5 are 1 (011100 reversed to position in vector)
    # Actually in Python code, index 0 is first char. 
    # Input "011100" means lights[0]=0, lights[1]=1, lights[2]=1, lights[3]=1, lights[4]=0, lights[5]=0
    # So initial should be binary 001110 (reversed) or simply 0x38 (56)
    initial = 0b0000000000111000 
    
    # Params for 6 lights
    params = [(5,3), (5,5), (2,4), (3,5), (4,2), (1,5)]
    a_vals = [p[0] for p in params] + [1] * 10
    b_vals = [p[1] for p in params] + [0] * 10
    
    dut.initial_states.value = initial
    for i in range(16):
        dut.a[i].value = a_vals[i]
        dut.b[i].value = b_vals[i]
        
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 2000
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    expected_max = 0
    for t in range(64):
        on_count = 0
        for i in range(6):
            # Initial state extraction from 'initial' variable
            init_bit = (initial >> i) & 1
            state = get_light_state(t, a_vals[i], b_vals[i], init_bit)
            if state == 1:
                on_count += 1
        if on_count > expected_max:
            expected_max = on_count
            
    dut._log.info(f"Test 3: Result {int(dut.max_lights.value)}, Expected {expected_max}")
    assert int(dut.max_lights.value) == expected_max, f"Mismatch: {int(dut.max_lights.value)} != {expected_max}"
    
    # Edge Case: All lights off
    dut.initial_states.value = 0
    for i in range(16):
        dut.a[i].value = 1
        dut.b[i].value = 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 2000
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    assert int(dut.max_lights.value) == 0, "All off should result in 0"
    
    dut._log.info(f"All tests passed. Total cycles taken: ~{timeout} (simulated)")
