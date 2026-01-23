import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_maze_solver(dut):
    """Test the maze solver module with various inputs"""
    
    # Clock generation
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.p_i.value = 0
    dut.current_room_index.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define MOD
    MOD = 1000000007
    
    # Test cases: [n, [p_1, p_2, ..., p_n], expected_output]
    # Note: p_i corresponds to the portal target from room i
    test_cases = [
        (2, [1, 2], 4),
        (4, [1, 1, 2, 3], 20),
        (5, [1, 1, 1, 1, 1], 62),
        (1, [1], 2),
        (3, [1, 1, 3], 8)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, p_list, expected in test_cases:
        # Initialize DP array (f)
        # f[0] = 0
        # We will compute f[1] to f[n]
        f = [0] * 10  # 0 to 8
        
        dut._log.info(f"Testing n={n}, p={p_list}, expected={expected}")
        
        for i in range(1, n + 1):
            # Wait for IDLE state (assume done is low or check state)
            # Since this is a simple sequential module, we drive inputs and wait for done
            
            dut.current_room_index.value = i
            dut.p_i.value = p_list[i-1]
            dut.start.value = 1
            
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done signal
            timeout = 0
            while not dut.done.value and timeout < 10:
                await RisingEdge(dut.clk)
                timeout += 1
            
            if timeout >= 10:
                raise TestFailure(f"Module did not complete for room {i}")
            
            # Read result
            result = int(dut.total_moves.value)
            
            # Verify against Python DP
            # Python logic: f[i] = (2 + 2*f[i-1] - f[p[i]-1]) % MOD
            # Note: p values in input are 1-indexed. f array is 0-indexed.
            # f[i] corresponds to room i+1.
            # The logic in prompt implies f[i] depends on f[i-1] and f[p[i]-1].
            # Let's align indices: f[i] is result for room i.
            
            p_val = p_list[i-1]
            
            if p_val == i:
                f[i] = (f[i-1] + 2) % MOD
            else:
                val = (2 + 2 * f[i-1] - f[p_val-1]) % MOD
                f[i] = val
            
            if result != f[i]:
                raise TestFailure(f"Room {i}: Expected {f[i]}, got {result}")
            
            # Wait for done to go low (transition to IDLE)
            await RisingEdge(dut.clk)
            
        # Final check for the full sequence
        if int(dut.total_moves.value) == expected:
            passed += 1
            dut._log.info(f"Test passed for n={n}")
        else:
            raise TestFailure(f"Final check failed for n={n}: Expected {expected}, got {dut.total_moves.value}")

    dut._log.info(f"Summary: {passed}/{total} tests passed")
