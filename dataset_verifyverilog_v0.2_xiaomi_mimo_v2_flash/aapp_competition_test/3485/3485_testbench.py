import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

def calculate_max_payout(cards):
    """Calculate maximum payout for Stop Counting! game"""
    n = len(cards)
    if n == 0:
        return 0.0
    
    # Best prefix average (cards 0..i for any i)
    best_prefix_avg = 0.0
    current_sum = 0
    for i in range(n):
        current_sum += cards[i]
        avg = current_sum / (i + 1)
        if avg > best_prefix_avg:
            best_prefix_avg = avg
    
    # Best suffix average (cards i..n-1 for any i)
    best_suffix_avg = 0.0
    current_sum = 0
    for i in range(n-1, -1, -1):
        current_sum += cards[i]
        avg = current_sum / (n - i)
        if avg > best_suffix_avg:
            best_suffix_avg = avg
    
    # Best pair: prefix 0..i and suffix j..n-1 where i < j
    best_pair_avg = 0.0
    
    # Precompute best prefix sum up to each index
    prefix_sums = []
    current_sum = 0
    for i in range(n):
        current_sum += cards[i]
        prefix_sums.append(current_sum)
    
    # Precompute best suffix sum from each index
    suffix_sums = []
    current_sum = 0
    for i in range(n-1, -1, -1):
        current_sum += cards[i]
        suffix_sums.insert(0, current_sum)
    
    # Find max sum of prefix ending before i and suffix starting after i
    for i in range(n):
        # Prefix can be any 0..j where j <= i-1
        # Suffix can be any k..n-1 where k >= i+1
        for j in range(i+1, n):
            for k in range(i+1, j+1):
                pass
    
    # Better approach: track best prefix sum and count
    best_prefix_sum = float('-inf')
    best_prefix_count = 1
    
    for split_point in range(n+1):
        # Cards before split_point can be counted
        prefix_avg = float('-inf')
        if split_point > 0:
            current_sum = sum(cards[:split_point])
            prefix_avg = current_sum / split_point
            if prefix_avg > best_prefix_avg:
                best_prefix_avg = prefix_avg
        
        # Cards after split_point can be counted
        suffix_avg = float('-inf')
        if split_point < n:
            current_sum = sum(cards[split_point:])
            suffix_avg = current_sum / (n - split_point)
            if suffix_avg > best_suffix_avg:
                best_suffix_avg = suffix_avg
    
    # Best pair approach: find i < j such that we count prefix 0..i and suffix j..n-1
    # We want to maximize (sum(0..i) + sum(j..n-1)) / ((i+1) + (n-j))
    # For hardware, we need to track this efficiently
    
    # Actually, the optimal is either:
    # 1. Some prefix
    # 2. Some suffix  
    # 3. A prefix AND a suffix (with gap in between)
    
    # For 3, we can iterate all i, j where i < j
    for i in range(n):
        prefix_sum = sum(cards[:i+1])
        prefix_len = i + 1
        for j in range(i+1, n+1):
            suffix_sum = sum(cards[j:])
            suffix_len = n - j
            if suffix_len == 0:
                # Just prefix
                avg = prefix_sum / prefix_len
                if avg > best_pair_avg:
                    best_pair_avg = avg
            else:
                total_sum = prefix_sum + suffix_sum
                total_len = prefix_len + suffix_len
                avg = total_sum / total_len
                if avg > best_pair_avg:
                    best_pair_avg = avg
    
    # Final answer is max of all three and 0
    result = max(0.0, best_prefix_avg, best_suffix_avg, best_pair_avg)
    return result

def float_to_q16_16(value):
    """Convert float to Q16.16 fixed-point format"""
    if value < 0:
        # Handle negative values
        int_part = int(value)
        frac_part = value - int_part
        # Q16.16: 16 integer bits, 16 fractional bits
        # For negative, use two's complement
        q_value = int(value * 65536)
        return q_value & 0xFFFFFFFF
    else:
        q_value = int(value * 65536)
        return q_value

def q16_16_to_float(q_value):
    """Convert Q16.16 fixed-point to float"""
    if q_value & 0x80000000:  # Negative
        return (q_value - 0x100000000) / 65536.0
    else:
        return q_value / 65536.0

@cocotb.test()
async def test_max_payout_basic(dut):
    """Test basic functionality with sample case 1"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_cards.value = 0
    for i in range(16):
        dut.card_values[i].value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Test case 1: 10 10 -10 -4 10 -> should get 10.0
    cards = [10, 10, -10, -4, 10]
    dut.num_cards.value = len(cards)
    for i, val in enumerate(cards):
        dut.card_values[i].value = val & 0xFFFF
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 100
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    # Check result
    result_q = dut.result.value
    result_float = q16_16_to_float(int(result_q))
    expected = 10.0
    
    print(f"Test 1 - Result: {result_float:.9f}, Expected: {expected:.9f}")
    assert abs(result_float - expected) < 0.0001, f"Expected {expected}, got {result_float}"
    print("Test 1 passed!")

@cocotb.test()
async def test_max_payout_all_negative(dut):
    """Test case with all negative values - should return 0"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Test case 2: -3 -1 -4 -1 -> should get 0.0
    cards = [-3, -1, -4, -1]
    dut.num_cards.value = len(cards)
    for i, val in enumerate(cards):
        dut.card_values[i].value = val & 0xFFFF
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 100
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result_q = dut.result.value
    result_float = q16_16_to_float(int(result_q))
    expected = 0.0
    
    print(f"Test 2 - Result: {result_float:.9f}, Expected: {expected:.9f}")
    assert abs(result_float - expected) < 0.0001, f"Expected {expected}, got {result_float}"
    print("Test 2 passed!")

@cocotb.test()
async def test_max_payout_mixed(dut):
    """Test case with mixed values"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Test case 3: 5 7 -10 -4 3 -> should get 6.0
    cards = [5, 7, -10, -4, 3]
    dut.num_cards.value = len(cards)
    for i, val in enumerate(cards):
        dut.card_values[i].value = val & 0xFFFF
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 100
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result_q = dut.result.value
    result_float = q16_16_to_float(int(result_q))
    expected = 6.0
    
    print(f"Test 3 - Result: {result_float:.9f}, Expected: {expected:.9f}")
    assert abs(result_float - expected) < 0.0001, f"Expected {expected}, got {result_float}"
    print("Test 3 passed!")

@cocotb.test()
async def test_max_payout_single_positive(dut):
    """Test with single positive card"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    cards = [42]
    dut.num_cards.value = 1
    dut.card_values[0].value = 42
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 100
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result_q = dut.result.value
    result_float = q16_16_to_float(int(result_q))
    expected = 42.0
    
    print(f"Test 4 - Result: {result_float:.9f}, Expected: {expected:.9f}")
    assert abs(result_float - expected) < 0.0001, f"Expected {expected}, got {result_float}"
    print("Test 4 passed!")

@cocotb.test()
async def test_max_payout_mixed_with_gap(dut):
    """Test case where best result involves a gap in middle"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # 10, 100, -50, -50, 100, 10
    # Best: count first 2 (avg 55) and last 2 (avg 55) = 110 total, 4 cards = 27.5
    # Or count all: 120/6 = 20
    # Or count just 100,100: 200/2 = 100
    cards = [10, 100, -50, -50, 100, 10]
    dut.num_cards.value = len(cards)
    for i, val in enumerate(cards):
        dut.card_values[i].value = val & 0xFFFF
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 100
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result_q = dut.result.value
    result_float = q16_16_to_float(int(result_q))
    # Best is 100,100 (avg 100) or maybe 10,100,100,10 (avg 55) or 100,100,10 (avg 70)
    # Let's check: prefix avg 10=10, 10,100=55, 10,100,-50=20, 10,100,-50,-50=2.5, 10,100,-50,-50,100=22, all=20
    # suffix avg 10=10, 100,10=55, -50,100,10=20, -50,-50,100,10=2.5, all=20
    # pairs: prefix 10,100 (55) + suffix 100,10 (55) = 110/4 = 27.5
    # prefix 10,100 (55) + suffix 10 (10) = 60/3 = 20
    # prefix 10 (10) + suffix 100,10 (55) = 60/3 = 20
    # prefix 10,100 (55) + suffix nothing = 55
    # prefix 10,100,-50 (20) + suffix 100,10 (55) = 175/5 = 35
    # prefix 10,100,-50,-50 (2.5) + suffix 100,10 (55) = 115/6 = 19.1667
    # prefix 10,100,-50,-50,100 (22) + suffix 10 (10) = 130/6 = 21.6667
    # Best is prefix 10,100,-50 (20) + suffix 100,10 (55) = 175/5 = 35
    # But wait, can we do prefix 10,100 (55) + suffix 100,10 (55) = 110/4 = 27.5
    # Actually, we can just count 100,100 = 200/2 = 100!
    # That's prefix 10,100,-50,-50,100 = 22? No, that's all 5 cards.
    # Counting cards 1 and 4 (indices 1,4): 100+100 = 200, 2 cards = 100
    # This is prefix 0..1 (10,100) and suffix 4..5 (100,10) but skipping -50,-50
    # Wait, Stop before card 2 (index 2), Start before card 4 (index 4)
    # Counted: indices 0,1,4,5 => 10,100,100,10 = 220/4 = 55
    # What about Stop before 0, Start after 5? None counted = 0
    # Stop before 2, Start after 3? Count indices 0,1,4,5 = 55
    # Stop before 2, never start? Count 0,1 = 55
    # Stop before 4, never start? Count 0,1,2,3 = 2.5
    # Never stop, Start after 3? Count 4,5 = 55
    # Never stop, Start after 4? Count 5 = 10
    # So best single segment is 55 (first two or last two)
    # But can we get 100? Count only cards at index 1 and 4 (both 100)? 
    # To count indices 1 and 4 but not 0,2,3,5, we need:
    # Start before 1? But must start before 1 means we've been counting before.
    # Actually, we can Stop before 1 (so 0 not counted) then Start before 4 (so 4,5 counted)
    # But that counts 4,5 not 1.
    # To count index 1 but not 0,2,3,4,5 is impossible because cards are in order.
    # So 55 is the best.
    expected = 55.0
    
    print(f"Test 5 - Result: {result_float:.9f}, Expected: {expected:.9f}")
    assert abs(result_float - expected) < 0.0001, f"Expected {expected}, got {result_float}"
    print("Test 5 passed!")

@cocotb.test()
async def test_max_payout_zero_cards(dut):
    """Test with zero cards - should return 0"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    dut.num_cards.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 100
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    result_q = dut.result.value
    result_float = q16_16_to_float(int(result_q))
    expected = 0.0
    
    print(f"Test 6 - Result: {result_float:.9f}, Expected: {expected:.9f}")
    assert abs(result_float - expected) < 0.0001, f"Expected {expected}, got {result_float}"
    print("Test 6 passed!")
    
    print("
All tests completed!")
