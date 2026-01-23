import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

def solve_python(hand, pile):
    n = 8
    
    # Find index of 1
    idx_1 = -1
    for i in range(n):
        if pile[i] == 1:
            idx_1 = i
            break
            
    consecutive = 0
    blocking = 0
    
    if idx_1 != -1:
        # Check consecutive
        is_consecutive = True
        for i in range(idx_1, n):
            expected = i - idx_1 + 1
            if pile[i] != expected:
                is_consecutive = False
                break
        
        if is_consecutive:
            consecutive = 1
            # Check blocking
            limit = n - (idx_1 - 1) # from logic: n - (j - 1) where j=idx_1
            for k in range(idx_1):
                if pile[k] != 0:
                    # Check if pile[k] - k <= limit
                    # Note: Python handles negative indices, but here k < idx_1
                    if pile[k] - k <= limit:
                        blocking = 1
                        break
    
    if consecutive and not blocking:
        return idx_1
    
    # Else calculate
    temp = -100
    for k in range(n):
        if pile[k] != 0:
            val = k - pile[k] + 2
            if val > temp:
                temp = val
    
    if temp == -100:
        # All pile cards are 0
        return n
        
    return temp + n

@cocotb.test()
def test_card_game_solver(dut):
    # Clock generation
    c = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(c.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.hand.value = 0
    dut.pile.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        ([0, 2, 0], [3, 0, 1]),
        ([0, 2, 0], [1, 0, 3]),
        ([0, 0, 0, 5, 0, 0, 0, 4, 0, 0, 11], [9, 2, 6, 0, 8, 1, 7, 0, 3, 0, 10]), # n=11, skip if we stick to n=8
        ([0]*8, [7, 8, 1, 2, 3, 4, 5, 6]),
        ([0]*8, [0, 6, 0, 0, 0, 1, 2, 3]),
        ([0]*8, [0, 1, 2, 3, 4, 5, 0, 6]),
        ([0]*8, [1, 2, 3, 4, 5, 6, 7, 8]),
        ([0]*8, [0, 1, 2, 3, 4, 5, 6, 7]),
        ([0]*8, [0, 0, 0, 0, 0, 0, 0, 0]), # All in hand
        ([0]*8, [2, 3, 1, 0, 0, 0, 0, 0]),
    ]
    
    expected = [
        2, 4, 0, 11, 5, 11, 0, 1, 8, 4
    ]
    
    # Filter for n=8 only
    valid_indices = [0, 1, 3, 4, 5, 6, 7, 8, 9]
    # Note: test case 0 and 1 are n=3. We must scale inputs to n=8 or ignore them.
    # The prompt says n=8. The inputs in list have n=8 or n=3.
    # Let's pad n=3 inputs to n=8 with 0s.
    
    run_cases = []
    
    # Case 1: n=3
    h = [0, 2, 0] + [0]*5
    p = [3, 0, 1] + [0]*5
    run_cases.append((h, p, 2))
    
    # Case 2
    h = [0, 2, 0] + [0]*5
    p = [1, 0, 3] + [0]*5
    run_cases.append((h, p, 4))
    
    # Case 3 (n=11) -> Scale to n=8? Skip or truncate. Let's skip n=11.
    
    # Case 4: 7 8 1 2 3 4 5 6
    h = [0]*8
    p = [7, 8, 1, 2, 3, 4, 5, 6]
    run_cases.append((h, p, 11))
    
    # Case 5: 0 6 0 0 0 1 2 3
    h = [0]*8
    p = [0, 6, 0, 0, 0, 1, 2, 3]
    run_cases.append((h, p, 5))
    
    # Case 6: 0 1 2 3 4 5 0 6
    h = [0]*8
    p = [0, 1, 2, 3, 4, 5, 0, 6]
    run_cases.append((h, p, 11))
    
    # Case 7: 1 2 3 4 5 6 7 8
    h = [0]*8
    p = [1, 2, 3, 4, 5, 6, 7, 8]
    run_cases.append((h, p, 0))
    
    # Case 8: 0 1 2 3 4 5 6 7
    h = [0]*8
    p = [0, 1, 2, 3, 4, 5, 6, 7]
    run_cases.append((h, p, 1))
    
    # Case 9: all 0
    h = [0]*8
    p = [0]*8
    run_cases.append((h, p, 8))
    
    # Case 10: 2 3 1 ...
    h = [0]*8
    p = [2, 3, 1, 0, 0, 0, 0, 0]
    run_cases.append((h, p, 4))

    passed = 0
    total = len(run_cases)
    
    for i, (h_in, p_in, exp) in enumerate(run_cases):
        # Pack inputs
        # Verilog input is [7:0] hand [0:7], pile [0:7]
        # In Python, we construct the value
        hand_val = 0
        for k in range(8):
            hand_val |= (h_in[k] << (8*k))
        
        pile_val = 0
        for k in range(8):
            pile_val |= (p_in[k] << (8*k))
            
        dut.hand.value = hand_val
        dut.pile.value = pile_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 50
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        else:
            raise TestFailure(f"Test {i+1}: Timeout waiting for done")
            
        res = int(dut.result.value)
        if res == exp:
            passed += 1
        else:
            dut._log.error(f"Test {i+1} Failed: Input H={h_in} P={p_in}. Expected {exp}, Got {res}")
            
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total
