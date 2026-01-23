import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

# Helper to calculate expected score (Python version of the logic)
def calculate_max_score(a, b):
    if a == 0:
        return -(b * b)
    if b == 0:
        return a * a
    
    # Strategy: Maximize 'o' blocks (1 block is best: a^2)
    # Minimize 'x' blocks penalty: Spread 'x' out.
    # If we have 1 'o' block, we can have 2 'x' blocks (x...x o ... o x...x)
    # If we have 1 'o' block, max 'x' blocks = 2.
    # Generally, if we have N 'o' blocks, max 'x' blocks = N + 1.
    
    # Case 1: 1 'o' block (score a^2)
    # Maximize 'x' blocks to minimize -x^2 penalty.
    # Number of 'x' blocks = min(b, a + 1)
    k1 = min(b, a + 1)
    base_x_score = 0
    # Distribute b into k1 blocks as evenly as possible
    q1, r1 = divmod(b, k1)
    score1 = a*a - (r1 * (q1 + 1)**2 + (k1 - r1) * q1**2)
    
    # Case 2: Try multiple 'o' blocks?
    # Actually, grouping 'o's is always better for score (by convexity).
    # So 1 'o' block is best for maximizing positive score.
    # But what if we want to minimize negative score?
    # The problem asks to maximize (positive - negative).
    # Positive part is a^2 if we group 'o's.
    # Negative part is minimized by splitting 'x's.
    
    # Is there ever a case where splitting 'o's helps?
    # Splitting 'o's reduces positive score: (x+y)^2 > x^2 + y^2.
    # It might allow more 'x' blocks? No, 'x' blocks are limited by 'o' blocks + 1.
    # So splitting 'o's reduces positive score, but allows more 'x' blocks (reducing negative score).
    # We must check if this tradeoff is worth it.
    
    best = score1
    
    # Try splitting 'o' into i blocks (i >= 2)
    # We need at least 2 'o's to split into 2 blocks.
    for i in range(2, min(a + 1, b + 1) + 1): # Limit i to avoid huge loops in Python
        if a < i: break
        # Distribute a into i blocks to maximize sum of squares -> unevenly
        # To maximize sum of squares of i blocks summing to a: make one block big, others 1.
        # Block sizes: (a - (i-1)) and (i-1) ones.
        o_score = (a - (i - 1))**2 + (i - 1)
        
        # Max 'x' blocks = i + 1
        k = min(b, i + 1)
        q, r = divmod(b, k)
        x_score = r * (q + 1)**2 + (k - r) * q**2
        
        total = o_score - x_score
        if total > best:
            best = total
            
    return best

@cocotb.test()
async def test_card_optimizer(dut):
    # Setup Clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.a_in.value = 0
    dut.b_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    # We limit a and b to small values (e.g., max 10) to fit the small design scope
    test_vectors = [
        (4, 0),
        (0, 4),
        (2, 3),
        (8, 6),
        (1, 1),
        (5, 5),
        (6, 2),
        (0, 1),
        (1, 0)
    ]
    
    passed = 0
    total = len(test_vectors)
    
    for a, b in test_vectors:
        # Apply inputs
        dut.a_in.value = a
        dut.b_in.value = b
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 50:
            await RisingEdge(dut.clk)
            timeout += 1
            
        if timeout >= 50:
            print(f"Timeout for a={a}, b={b}")
            continue
            
        # Get result
        actual = int(dut.max_score.value)
        if actual.signed_value < 0:
            actual = actual.signed_value
        else:
            actual = int(dut.max_score.value)
            
        expected = calculate_max_score(a, b)
        
        if actual == expected:
            passed += 1
        else:
            print(f"Test failed for a={a}, b={b}: Expected {expected}, Got {actual}")
            
    print(f"{passed}/{total} tests passed")
    assert passed == total, "Some tests failed"
