import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_p2p_streaming(dut):
    """Test P2P streaming optimization with 4 users"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: Original example scaled
    # Input: 3 users, C=20 -> scaled to 4 users, C=20
    # But we need to scale to 8-bit values
    # User 0: p=50, b=70, u=10
    # User 1: p=100, b=110, u=4
    # User 2: p=150, b=190, u=16
    # We'll add a 4th dummy user with p=0, b=0, u=0
    # Scale by factor of 2: divide by 2
    # p: 25, 50, 75, 0
    # b: 35, 55, 95, 0
    # u: 5, 2, 8, 0
    # C=10
    
    dut.p_i[0].value = 25
    dut.p_i[1].value = 50
    dut.p_i[2].value = 75
    dut.p_i[3].value = 0
    
    dut.b_i[0].value = 35
    dut.b_i[1].value = 55
    dut.b_i[2].value = 95
    dut.b_i[3].value = 0
    
    dut.u_i[0].value = 5
    dut.u_i[1].value = 2
    dut.u_i[2].value = 8
    dut.u_i[3].value = 0
    
    dut.C.value = 10
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (up to 120 cycles)
    for _ in range(120):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    # Expected result: scaled version of 5
    # Original output was 5
    # With scaling factor 2, result should be 2.5 (or 2 in integer)
    # But Q8.8 format: 2.5 * 256 = 640 -> 0x0280
    print(f"Test 1 - Result: {int(dut.result.value)} (hex: {hex(int(dut.result.value))})")
    assert dut.done.value == 1, "Done signal not asserted"
    
    # Test case 2: Second example
    # 4 users: (0,50,100), (0,50,100), (0,50,100), (1000,1500,100)
    # C=100
    # Scale down: divide by 50
    # p: 0,0,0,20
    # b: 1,1,1,30
    # u: 2,2,2,2
    # C=2
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    dut.p_i[0].value = 0
    dut.p_i[1].value = 0
    dut.p_i[2].value = 0
    dut.p_i[3].value = 20
    
    dut.b_i[0].value = 1
    dut.b_i[1].value = 1
    dut.b_i[2].value = 1
    dut.b_i[3].value = 30
    
    dut.u_i[0].value = 2
    dut.u_i[1].value = 2
    dut.u_i[2].value = 2
    dut.u_i[3].value = 2
    
    dut.C.value = 2
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(120):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    print(f"Test 2 - Result: {int(dut.result.value)} (hex: {hex(int(dut.result.value))})")
    assert dut.done.value == 1, "Done signal not asserted"
    
    # Test case 3: Edge case - all users need upload
    # 2 users: p=10,b=10,u=5; p=10,b=10,u=5; C=5
    # Both have zero buffer, need B+5 bytes, total need 2*(B+5)
    # Total upload 10, so B+5=5, B=0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    dut.p_i[0].value = 10
    dut.p_i[1].value = 10
    dut.p_i[2].value = 0
    dut.p_i[3].value = 0
    
    dut.b_i[0].value = 10
    dut.b_i[1].value = 10
    dut.b_i[2].value = 0
    dut.b_i[3].value = 0
    
    dut.u_i[0].value = 5
    dut.u_i[1].value = 5
    dut.u_i[2].value = 0
    dut.u_i[3].value = 0
    
    dut.C.value = 5
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(120):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    print(f"Test 3 - Result: {int(dut.result.value)} (hex: {hex(int(dut.result.value))})")
    assert dut.done.value == 1, "Done signal not asserted"
    
    print(f"
All tests completed. Results shown above.")
    print(f"Note: In Q8.8 format, value 640 = 2.5, value 0 = 0, value -128 = -0.5")
