import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_powers_game(dut):
    """Test powers_game module with various n values"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (n, expected_winner) where 1=Vasya, 0=Petya
    test_cases = [
        (1, 1),   # Vasya
        (2, 0),   # Petya  
        (3, 1),   # Vasya
        (4, 1),   # Vasya
        (5, 1),   # Vasya
        (6, 1),   # Vasya
        (7, 1),   # Vasya
        (8, 0),   # Petya
        (9, 1),   # Vasya
        (10, 1),  # Vasya
        (16, 1),  # Vasya
        (24, 1),  # Vasya
        (25, 1),  # Vasya
        (27, 1),  # Vasya
        (32, 0),  # Petya
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, expected in test_cases:
        # Set inputs
        dut.n.value = n
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 200 cycles)
        timeout = 200
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        else:
            raise TestFailure(f"Timeout for n={n}")
        
        # Check result
        actual = int(dut.winner.value)
        if actual == expected:
            passed += 1
            print(f"✓ n={n}: {'Vasya' if actual else 'Petya'} (correct)")
        else:
            print(f"✗ n={n}: expected {'Vasya' if expected else 'Petya'}, got {'Vasya' if actual else 'Petya'}")
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"

@cocotb.test()
async def test_edge_cases(dut):
    """Test edge cases"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test n=256 (max for 8-bit)
    dut.n.value = 256
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait
    for _ in range(200):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    result = int(dut.winner.value)
    print(f"n=256: {'Vasya' if result else 'Petya'}")
    assert dut.done.value, "Did not complete"
    
    # Test n=1
    dut.n.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(200):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    result = int(dut.winner.value)
    assert result == 1, f"n=1 should be Vasya, got {'Petya' if result == 0 else 'Vasya'}"
    print("Edge cases passed")
