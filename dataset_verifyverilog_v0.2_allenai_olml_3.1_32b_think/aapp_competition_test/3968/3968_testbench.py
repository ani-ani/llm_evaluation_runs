import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

# Helper to convert integer to binary string for masking
def time_to_mask(start, end):
    mask = 0
    if start <= end:
        for t in range(start, end + 1):
            if t < 16:
                mask |= (1 << t)
    return mask

# Helper to calculate ground truth
def calculate_spread(init_infected, schedules, D):
    # schedules: list of (start, end) tuples for 8 people
    # init_infected: list of indices
    # D: days
    
    N = 8
    infected = [False] * N
    for i in init_infected:
        infected[i] = True
        
    # Build time masks
    time_masks = []
    for i in range(N):
        start, end = schedules[i]
        mask = 0
        # Limit to 16 time slots for the scaled problem
        if start <= end:
            for t in range(start, min(end, 16) + 1):
                mask |= (1 << t)
        time_masks.append(mask)
        
    # Build Contact Graph (bitwise overlap)
    contact = [[False]*N for _ in range(N)]
    for i in range(N):
        for j in range(N):
            if (time_masks[i] & time_masks[j]) != 0:
                contact[i][j] = True
            
    # Simulate Days
    for day in range(D):
        new_infections = [False] * N
        for i in range(N):
            if infected[i]:
                for j in range(N):
                    if not infected[j] and contact[i][j]:
                        new_infections[j] = True
        
        for i in range(N):
            if new_infections[i]:
                infected[i] = True
                
    return infected

@cocotb.test()
async def test_virus_spread(dut):
    """Test the virus spread simulation for 8 people, 16 time slots, up to 4 days."""
    
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Cases
    # Case 1: Simple chain spread
    # Person 0: t=0-1 (Always present)
    # Person 1: t=1-2 (Overlaps 0 at t=1)
    # Person 2: t=2-3 (Overlaps 1 at t=2)
    # Person 3: t=3-4 (Overlaps 2 at t=3)
    # Init: Infected = {0}. Days = 3. Expect: {0,1,2,3}
    
    schedules = [
        (0, 1), (1, 2), (2, 3), (3, 4),
        (10, 10), (10, 10), (10, 10), (10, 10)
    ]
    init_mask = 1 << 0  # Person 0 infected
    D = 3
    
    # Load inputs
    for i in range(8):
        dut.p_start_t[i].value = schedules[i][0]
        dut.p_end_t[i].value = schedules[i][1]
    
    dut.init_infected.value = init_mask
    dut.D.value = D
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (D cycles + processing latency)
    # The module should count D cycles from start
    for _ in range(D + 2): # Allow some buffer
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    if dut.done.value != 1:
        raise TestFailure(f"Done signal not high after {D+2} cycles")
        
    result = int(dut.infected_status.value)
    expected = calculate_spread([0], schedules, D)
    
    # Convert expected list to mask
    expected_mask = 0
    for i in range(8):
        if expected[i]:
            expected_mask |= (1 << i)
            
    print(f"Test Case 1: D={D}, Init={init_mask:b}")
    print(f"Result Mask: {result:08b} (Expected: {expected_mask:08b})")
    
    if result != expected_mask:
        raise TestFailure(f"Mismatch! Got {result:08b}, expected {expected_mask:08b}")

    # Case 2: Simultaneous Infection (Day 1)
    # Person 0 (t=0-2) infected init. Person 1 (t=1-3) uninfected.
    # They overlap at t=1,2. 
    # Person 2 (t=2-4) uninfected. Overlaps Person 1 at t=2, but NOT Person 0 directly if t=2 is boundary.
    # Actually, let's make it simpler:
    # P0: 0-2 (Infected)
    # P1: 1-1 (Uninfected) -> Overlaps P0 at t=1. Gets infected Day 1.
    # P2: 2-2 (Uninfected) -> Overlaps P0 at t=2. Gets infected Day 1.
    # D=1. Expected: P0, P1, P2.
    
    schedules_2 = [
        (0, 2), (1, 1), (2, 2),
        (10, 10), (10, 10), (10, 10), (10, 10), (10, 10)
    ]
    init_mask_2 = 1 << 0
    D_2 = 1
    
    for i in range(8):
        dut.p_start_t[i].value = schedules_2[i][0]
        dut.p_end_t[i].value = schedules_2[i][1]
    dut.init_infected.value = init_mask_2
    dut.D.value = D_2
    
    # Reset for next run (simplified reset sequence)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(D_2 + 2):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    result = int(dut.infected_status.value)
    expected = calculate_spread([0], schedules_2, D_2)
    expected_mask = 0
    for i in range(8):
        if expected[i]:
            expected_mask |= (1 << i)
            
    print(f"Test Case 2: D={D_2}, Init={init_mask_2:b}")
    print(f"Result Mask: {result:08b} (Expected: {expected_mask:08b})")
    
    if result != expected_mask:
        raise TestFailure(f"Mismatch! Got {result:08b}, expected {expected_mask:08b}")

    # Case 3: No Contact
    # P0: 0-0. P1: 1-1. D=1. Expect only P0.
    schedules_3 = [
        (0, 0), (1, 1), (10, 10), (10, 10),
        (10, 10), (10, 10), (10, 10), (10, 10)
    ]
    init_mask_3 = 1 << 0
    D_3 = 1
    
    for i in range(8):
        dut.p_start_t[i].value = schedules_3[i][0]
        dut.p_end_t[i].value = schedules_3[i][1]
    dut.init_infected.value = init_mask_3
    dut.D.value = D_3
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(D_3 + 2):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    result = int(dut.infected_status.value)
    expected = calculate_spread([0], schedules_3, D_3)
    expected_mask = 0
    for i in range(8):
        if expected[i]:
            expected_mask |= (1 << i)
            
    print(f"Test Case 3: D={D_3}, Init={init_mask_3:b}")
    print(f"Result Mask: {result:08b} (Expected: {expected_mask:08b})")
    
    if result != expected_mask:
        raise TestFailure(f"Mismatch! Got {result:08b}, expected {expected_mask:08b}")

    print("All tests passed!")
