import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

# Precompute BFS solution for the bounded problem
def precompute_costs():
    primes = [3, 5, 7, 11, 13]
    max_cards = 16
    max_states = 1 << max_cards
    
    # BFS to find minimum steps to state 0
    costs = [-1] * max_states
    queue = [0]
    costs[0] = 0
    
    idx = 0
    while idx < len(queue):
        curr = queue[idx]
        idx += 1
        
        for p in primes:
            if p > max_cards:
                continue
            for start in range(max_cards - p + 1):
                # Create mask for this flip
                flip_mask = 0
                for i in range(p):
                    flip_mask |= (1 << (start + i))
                
                next_state = curr ^ flip_mask
                if costs[next_state] == -1:
                    costs[next_state] = costs[curr] + 1
                    queue.append(next_state)
    
    # Fill any unreachable states (should not exist for our small graph)
    for i in range(max_states):
        if costs[i] == -1:
            costs[i] = 255 # Mark as unreachable
    
    return costs

@cocotb.test()
async def test_snuke_flip_solver(dut):
    """Test the snuke flip solver module"""
    
    # Generate expected costs
    expected_costs = precompute_costs()
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.card_mask.value = 0
    await Timer(30, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (card_mask, expected_result)
    # Note: card_mask bits: bit i = card (i+1)
    # card_mask = 0 is always 0 cost
    test_cases = [
        (0, 0),           # No cards up
        (1 << 3 | 1 << 4, 2),  # Cards 4,5 (sample case: mask has bit 3,4 set) -> expected 2
        (1 << 0, 3),      # Card 1 only
        (1 << 1, 2),      # Card 2 only
        (1 << 0 | 1 << 1, 2), # Cards 1,2
        (1 << 2 | 1 << 3, 2), # Cards 3,4
        (1 << 15, 3),     # Card 16 only
        ((1 << 16) - 1, 6), # All cards up (max depth test)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for mask, expected in test_cases:
        # Input
        dut.card_mask.value = mask
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (max 3 cycles)
        timeout = 10
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Check result
        actual = int(dut.result.value)
        
        # Allow 255 for unreachable (shouldn't happen with valid inputs)
        if actual == expected or (expected == 255 and actual == 255):
            passed += 1
            dut._log.info(f"Mask {mask:016b}: OK (Got {actual}, Exp {expected})")
        else:
            dut._log.error(f"Mask {mask:016b}: FAIL (Got {actual}, Exp {expected})")
    
    dut._log.info(f"Tests passed: {passed}/{total}")
    assert passed == total, f"Only {passed}/{total} tests passed"
