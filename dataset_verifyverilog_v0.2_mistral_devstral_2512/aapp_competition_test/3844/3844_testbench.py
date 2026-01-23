import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_card_game(dut):
    """Test the card_game module with various inputs"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to drive input array
    def set_inputs(cards):
        # Pad to 16 elements with 0s
        padded = cards + [0] * (16 - len(cards))
        # Create a 128-bit value representing the packed array
        # In cocotb, we can assign the array directly if it's unpacked, or pack it
        # Verilog 'input [7:0] data_in [15:0]' is unpacked. 
        # In Python cocotb, we usually construct a packed value or iterate.
        # Let's assume the testbench sees it as a LogicArray that we can slice or pack.
        # Construct packed value: data_in[15] << 120 ... data_in[0] << 0
        packed_val = 0
        for i, val in enumerate(padded):
            packed_val |= (val << (i * 8))
        dut.data_in.value = packed_val
        return padded

    # Helper to wait for done
    async def wait_done():
        for _ in range(100): # Safety timeout
            if dut.done.value == 1:
                return
            await RisingEdge(dut.clk)
        raise TimeoutError("Module did not finish in time")

    test_cases = [
        ([4, 5, 7], "Conan"),           # 3 distinct, all odd counts
        ([1, 1], "Agasa"),              # 1 repeated, even count
        ([1, 1, 1], "Conan"),           # 1 repeated, odd count
        ([2, 2, 3, 3], "Agasa"),        # Multiple evens
        ([2, 2, 3], "Conan"),           # Mixed parities, max is 3 (odd)
        ([1, 2, 2], "Conan"),           # Max 2 (even), but 1 (odd) exists
        ([5, 5, 5, 5, 5], "Conan"),     # Single odd
        ([10, 20, 30, 40], "Conan"),    # All distinct (odd counts of 1)
        ([100, 100, 100, 100], "Agasa") # Single even
    ]

    passed = 0
    total = len(test_cases)

    for cards, expected_str in test_cases:
        print(f"Testing input: {cards} -> Expected: {expected_str}")
        
        padded_cards = set_inputs(cards)
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        await wait_done()
        
        # Check result
        # expected_str == "Conan" means result should be 1
        expected_bit = 1 if expected_str == "Conan" else 0
        
        if int(dut.result.value) == expected_bit:
            passed += 1
            print(f"  PASS: Got {'Conan' if dut.result.value else 'Agasa'}")
        else:
            print(f"  FAIL: Got {'Conan' if dut.result.value else 'Agasa'}, expected {expected_str}")
        
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk) # Gap between tests

    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Test failed: {passed}/{total} passed"
