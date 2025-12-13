import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import random

@cocotb.test()
async def test_validator(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases (adapted to n≤8)
    # Convert friends list to 8-bit masks: [0b00000001, 0b00000011, ...]
    test_cases = [
        {  # TC1: Sample Input 1 - Expected valid (home)
            "n": 4, "p": 2, "q": 1,
            "friends": [0b0010, 0b0101, 0b1010, 0b0100],
            "expected": 0  # home
        },
        {  # TC2: Sample Input 2 - Expected invalid (detention)
            "n": 5, "p": 2, "q": 1,
            "friends": [0b0010, 0b0101, 0b10110, 0b01100, 0b01000],
            "expected": 1  # detention
        },
        {  # TC3: Small case that should fail
            "n": 3, "p": 3, "q": 3,
            "friends": [0b0110, 0b1001, 0b1001],
            "expected": 1  # detention
        }
    ]
    
    passed = 0
    for i, tc in enumerate(test_cases):
        # Apply inputs
        dut.n.value = tc["n"]
        dut.p.value = tc["p"]
        dut.q.value = tc["q"]
        for j in range(8):
            # Initialize all friends masks (zero-pad beyond actual n)
            val = tc["friends"][j] if j < tc["n"] else 0
            dut.friends[j].value = val if j < 8 else 0
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for processing (n+2 cycles)
        cycles = tc["n"] + 2
        for _ in range(cycles):
            await RisingEdge(dut.clk)
        
        # Check outputs
        if dut.done.value != 1:
            dut._log.error(f"Test {i} timed out")
        else:
            result = dut.decision.value
            if result == tc["expected"]:
                passed += 1
            else:
                dut._log.error(f"TC{i} failed: Got {result}, expected {tc['expected']}")
        # Wait a cycle between tests
        await RisingEdge(dut.clk)
    
    dut._log.info(f"Tests passed: {passed}/{len(test_cases)}")