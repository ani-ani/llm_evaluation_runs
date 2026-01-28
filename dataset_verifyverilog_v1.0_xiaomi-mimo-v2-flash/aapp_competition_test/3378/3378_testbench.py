import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 16
ADDR_WIDTH = 3
MAX_SEG = 8
NUM_TICKETS = 8
CLK_NS = 10
MAX_CYCLES = 5000

# Helpers

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits - 1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Solver Logic for Verification

def solve_python(tour, tickets):
    # tour: list of 0-indexed cities (0-3)
    # tickets: list of (src, dst, type, price)
    d = len(tour)
    
    # Precompute min costs for direct flights
    # cost_one[src][dst] = min price of O ticket
    # cost_round[src][dst] = min price of R ticket (or min cost to fly there and back if paired)
    INF = 10**12
    cost_one = [[INF]*4 for _ in range(4)]
    cost_round = [[INF]*4 for _ in range(4)]
    
    for s, dst, t_type, p in tickets:
        if t_type == 'O':
            cost_one[s][dst] = min(cost_one[s][dst], p)
        else:
            cost_round[s][dst] = min(cost_round[s][dst], p)
    
    # DP over bitmask of segments covered
    num_masks = 1 << d
    dp = [INF] * num_masks
    dp[0] = 0
    
    for mask in range(num_masks):
        if dp[mask] == INF:
            continue
        
        # Find first unvisited segment
        first_unvisited = -1
        for i in range(d):
            if not (mask & (1 << i)):
                first_unvisited = i
                break
        
        if first_unvisited == -1:
            continue
            
        u = tour[first_unvisited] # src is tour[i]
        # The destination is tour[first_unvisited] in the problem description logic check
        # Wait, the tour is a_1, a_2, ..., a_d.
        # We need to fly from a_i to a_{i+1}.
        # The segments are (a_0->a_1), (a_1->a_2), ..., (a_{d-2}->a_{d-1}).
        # The input gives a_1...a_d. So segments are (a_1->a_2) etc.
        # Let's adjust indices. 
        # tour input: [a1, a2, a3, ...]
        # segment i is from tour[i] to tour[i+1].
        
        src = tour[first_unvisited]
        dst = tour[first_unvisited + 1] # This works up to d-1. The last element a_d is start.
        
        # Option 1: Buy One-way ticket for this segment
        p_one = cost_one[src][dst]
        if p_one != INF:
            new_mask = mask | (1 << first_unvisited)
            dp[new_mask] = min(dp[new_mask], dp[mask] + p_one)
            
        # Option 2: Buy Round trip ticket for this segment
        p_round = cost_round[src][dst]
        if p_round != INF:
            # This covers the forward leg. 
            # It also covers the return leg (dst->src) if that segment exists in the tour later.
            # Find a matching return segment later in the tour
            for j in range(first_unvisited + 1, d):
                u_j = tour[j]
                v_j = tour[j+1] # careful with boundary, last segment is (a_{d-1} -> a_d)
                # Actually the tour has d cities. d-1 segments.
                # Wait, problem says d concerts. Cities a_1...a_d.
                # Segments: a_1->a_2, ..., a_{d-1}->a_d.
                # The input array length is d. Indices 0 to d-1.
                # Segment i uses a[i] -> a[i+1].
                # The loop variable j goes from 0 to d-2.
                # In the mask, we have bits for segments 0 to d-2.
                pass
            
            # Let's simplify for the HDL. 
            # The "Round Trip" value comes into play if we have a flight A->B and later B->A.
            # We will track the cheapest cost to fly A->B as One-way and Round-trip.
            # In the DP, if we choose Round-trip for A->B, we check if B->A exists later.
            # If B->A exists at index k, and k is not in mask, we can potentially cover both.
            
            # Search for return leg
            found_return = False
            for k in range(first_unvisited + 1, d):
                if not (mask & (1 << k)):
                    ret_src = tour[k]
                    ret_dst = tour[k+1]
                    if ret_src == dst and ret_dst == src:
                        new_mask = mask | (1 << first_unvisited) | (1 << k)
                        dp[new_mask] = min(dp[new_mask], dp[mask] + p_round)
                        found_return = True
                        break # Only pair with the first matching return leg found?
                        # Strictly speaking, we should pair optimally, but greedy pairing is valid for optimal cost if prices are fixed.
                        # However, to be correct, we should consider it just adds capability.
                        # But since we buy a ticket to fly there and back, we consume 2 segments.
            
            if not found_return:
                # Just cover the forward leg (wasting return leg)
                new_mask = mask | (1 << first_unvisited)
                dp[new_mask] = min(dp[new_mask], dp[mask] + p_round)

    return dp[num_masks - 1]

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_tour_optimization(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test Case 1: Sample Input 1
    # Cities: 1-2. Tour: 1 2 1 2 1 (Segments: 1->2, 2->1, 1->2, 2->1)
    # Tickets:
    # 1 2 R 6
    # 1 2 O 3
    # 2 1 O 3
    # 1 2 R 5
    # 
    # Analysis:
    # Segments: 0:1->2, 1:2->1, 2:1->2, 3:2->1
    # Cheapest One-way: 1->2 is 3, 2->1 is 3.
    # Cheapest Round: 1->2 is 5 (covers 1->2 and 2->1)
    # Optimal: Buy 1 Round Trip (5) + 1 One-way (3) = 8? No.
    # Segments: 0,1,2,3.
    # Pair (0,1) with Round Trip (5). Pair (2,3) with Round Trip (5). Total 10.
    # Or 4 One-ways: 3+3+3+3 = 12.
    # Or 1 Round (0), 1 One (1), 1 One (2), 1 One (3) = 5+3+3+3 = 14.
    # Wait, the sample output is 10.
    
    # Let's prepare inputs.
    # Map 1->0, 2->1 for internal logic
    tour_seg = [0, 1, 0, 1, 0] # 1 2 1 2 1
    # Segments needed: 0->1, 1->0, 0->1, 1->0
    
    tickets = [
        (0, 1, 'R', 6),
        (0, 1, 'O', 3),
        (1, 0, 'O', 3),
        (0, 1, 'R', 5)
    ]
    
    expected = solve_python(tour_seg, tickets)
    
    cocotb.log.info(f"Expected result: {expected}")
    
    # Load inputs into DUT
    # Tour segments: 8 inputs (we pad 0 if shorter)
    for i in range(MAX_SEG):
        val = tour_seg[i] if i < len(tour_seg) - 1 else 0 # Only d-1 segments are needed for flights
        # Actually, the prompt says `tour_seg` is the sequence of cities.
        # We need d cities. If d=5, we have 5 cities, 4 flights.
        # The DUT interface in prompt said `tour_seg [0:7]` array of cities.
        # And we fly between consecutive.
        # Let's pass the full sequence.
        dut.tour_seg[i].value = tour_seg[i]
        
    # Load Tickets (we have 4 real tickets, need to fill 8 slots)
    # We'll fill dummy tickets with high prices or invalid routes to avoid affecting min
    for i in range(NUM_TICKETS):
        if i < len(tickets):
            s, d, t, p = tickets[i]
            dut.ticket_s[i].value = s
            dut.ticket_d[i].value = d
            dut.ticket_t[i].value = (1 if t == 'R' else 0)
            dut.ticket_p[i].value = p
        else:
            # Dummy ticket: 0->0, O, Price Max
            dut.ticket_s[i].value = 0
            dut.ticket_d[i].value = 0
            dut.ticket_t[i].value = 0
            dut.ticket_p[i].value = 65535

    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    result = int(dut.result.value)
    if result != expected:
        raise TestFailure(f"Case 1 failed: Expected {expected}, got {result}")
    
    cocotb.log.info("Case 1 passed")

    # Test Case 2
    # 4 10
    # 1 2 3 1 2 1 3 2 4 1
    # 9 tickets
    # Output 60
    
    # Reset
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    tour_seg_2 = [0, 1, 2, 0, 1, 0, 2, 1, 3, 0] # 1->4 mapped to 0->3
    tickets_2 = [
        (1, 3, 'O', 10), # 2->4
        (0, 2, 'R', 1),  # 1->3
        (2, 0, 'R', 10), # 3->1
        (1, 2, 'R', 20), # 2->3
        (0, 1, 'R', 10), # 1->2
        (0, 1, 'O', 20),
        (1, 2, 'O', 5),
        (2, 1, 'O', 5),
        (3, 0, 'O', 10)  # 4->1
    ]
    
    # Adjust indices: Input cities 1-4 -> 0-3
    # The provided ticket list in python needs adjustment
    # 2 4 O 10 -> (1, 3, 'O', 10)
    # 1 3 R 1 -> (0, 2, 'R', 1)
    # 3 1 R 10 -> (2, 0, 'R', 10)
    # 2 3 R 20 -> (1, 2, 'R', 20)
    # 1 2 R 10 -> (0, 1, 'R', 10)
    # 1 2 O 20 -> (0, 1, 'O', 20)
    # 2 3 O 5 -> (1, 2, 'O', 5)
    # 3 2 O 5 -> (2, 1, 'O', 5)
    # 4 1 O 10 -> (3, 0, 'O', 10)
    
    expected_2 = solve_python(tour_seg_2, tickets_2)
    cocotb.log.info(f"Expected result 2: {expected_2}")
    
    # Load inputs
    for i in range(MAX_SEG):
        val = tour_seg_2[i] if i < len(tour_seg_2) else 0
        dut.tour_seg[i].value = val
    
    for i in range(NUM_TICKETS):
        s, d, t, p = tickets_2[i]
        dut.ticket_s[i].value = s
        dut.ticket_d[i].value = d
        dut.ticket_t[i].value = (1 if t == 'R' else 0)
        dut.ticket_p[i].value = p
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    result_2 = int(dut.result.value)
    if result_2 != expected_2:
        raise TestFailure(f"Case 2 failed: Expected {expected_2}, got {result_2}")
    
    cocotb.log.info("Case 2 passed")