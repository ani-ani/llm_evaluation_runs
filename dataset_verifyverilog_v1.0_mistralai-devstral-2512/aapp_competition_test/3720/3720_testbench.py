import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

def is_power(n):
    if n <= 1:
        return True
    # Check if n is a perfect power
    # Iterate bases b from 2 to sqrt(n)
    limit = int(math.isqrt(n))
    for b in range(2, limit + 1):
        p = b * b
        while p <= n:
            if p == n:
                return True
            p *= b
            if p > n:
                break
    return False

def calculate_winner_py(n):
    # This matches the reference Python solution logic adapted for clarity
    # XOR sum of Grundy numbers
    # 1 has Grundy 1
    # Other numbers form chains. Chain length L -> Grundy L % 2
    # We need to count the number of non-power numbers in [2, n] plus the contribution of 1.
    # Wait, the reference solution uses a specific array and log logic.
    # Let's use the parity approach which is equivalent.
    # Non-powers are generators. 1 is a special generator.
    # Count non-powers in 2..n. Add 1 (for number 1).
    # If total count is odd, Vasya wins.
    
    if n == 1:
        return 1 # Vasya
        
    # Count non-powers in range 2..n
    # Total numbers in 2..n is n-1
    # Powers in 2..n are those x^k where k>=2 and x>=2.
    # We iterate bases x from 2 to sqrt(n). 
    # If x is not a power, we count its distinct powers x^2, x^3... <= n.
    # Note: squares of non-powers are distinct.
    
    limit = int(math.isqrt(n))
    powers_count = 0
    is_p = [False] * (limit + 1)
    
    for i in range(2, limit + 1):
        if is_p[i]:
            continue
        # i is a base (not a power of smaller number)
        p = i * i
        while p <= n:
            if p <= limit:
                is_p[p] = True
            powers_count += 1
            if p > n // i:
                break
            p *= i
            
    # Number of non-powers in 2..n = (n - 1) - powers_count
    # Add 1 for the number 1 (which is a non-power that removes nothing)
    # Total active positions (equivalent to pile size in Nim)
    # Actually, the parity of (non-powers + 1) determines the winner.
    # Non-powers = (n - 1) - powers_count
    # Total = n - powers_count
    
    total_piles = n - powers_count
    winner = 1 if (total_piles % 2 == 1) else 0
    return winner

async def wait_for_done(dut, max_cycles=50000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            return
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=30000, timeout_unit="ms")
async def test_powers_game(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    test_cases = [
        (1, 1), (2, 0), (3, 1), (4, 1), (5, 1), (6, 1), (7, 1), (8, 0),
        (9, 1), (10, 1), (11, 1), (12, 1), (13, 1), (14, 1), (15, 1), (16, 1),
        (17, 1), (18, 1), (19, 1), (20, 1), (21, 1), (22, 1), (23, 1), (24, 1),
        (25, 1), (26, 1), (27, 1), (28, 1), (52, 0), (53, 1),
        (200, 1), (246, 0), (247, 1), (248, 0), (249, 1), (250, 0),
        (10153, 0), (10154, 1), (10155, 0),
        (200702, 1), (200703, 0), (200704, 1), (200705, 0), (200706, 1),
        (19000880, 1), (19000881, 0), (19000882, 1), (19000883, 0),
        (999999998, 1), (999999999, 1), (1000000000, 1),
        (951352334, 0), (951352336, 1),
        (956726760, 1), (956726762, 0),
        (940219568, 1), (940219570, 0),
        (989983294, 1), (989983296, 1),
        (987719182, 1), (987719184, 1),
        (947039074, 1), (947039076, 1),
        (988850914, 1), (988850916, 1),
        (987656328, 1), (987656330, 1),
        (954377448, 1), (954377450, 1),
        (992187000, 1), (992187002, 1),
        (945070562, 0), (945070564, 1),
        (959140898, 1), (959140900, 1),
        (992313000, 1), (992313002, 1),
        (957097968, 1), (957097970, 1),
        (947900942, 1), (947900944, 1),
    ]
    
    for n_input, expected_winner in test_cases:
        cocotb.log.info(f"Testing n={n_input}, Expected={'Vasya' if expected_winner else 'Petya'}")
        
        await reset_dut(dut)
        
        dut.n_in.value = n_input
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        await wait_for_done(dut)
        
        result = int(dut.winner.value)
        if result != expected_winner:
            raise TestFailure(f"For n={n_input}, expected {'Vasya' if expected_winner else 'Petya'}, got {'Vasya' if result else 'Petya'}")
