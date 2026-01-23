import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_packet_solver(dut):
    """Test packet solver module"""
    
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (n, expected_result)
    test_cases = [
        (6, 3),     # Binary 110 -> 3 bits
        (2, 2),     # Binary 10 -> 2 bits
        (1, 1),     # Binary 1 -> 1 bit
        (0, 0),     # Edge case: 0 requires 0 packets
        (255, 8),   # Binary 11111111 -> 8 bits
        (256, 9),   # Binary 100000000 -> 9 bits
        (65535, 16) # Max 16-bit value
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n_val, expected in test_cases:
        # Start transaction
        dut.n.value = n_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal
        timeout = 50
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        # Check result
        actual = int(dut.result.value)
        if actual == expected:
            passed += 1
        else:
            raise TestFailure(f"Test failed for n={n_val}: expected {expected}, got {actual}")
        
        await RisingEdge(dut.clk)
    
    print(f"{passed}/{total} tests passed")
