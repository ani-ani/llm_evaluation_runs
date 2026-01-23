import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

def compute_expected(s, n, m, lines):
    """Compute expected latest departure using Python BFS"""
    # Build adjacency list for reverse traversal
    # lines: list of (u, v, t0, p, d)
    
    # We'll compute latest arrival at each stop
    # Start from destination (n-1) with arrival time s
    latest_arrival = [-1] * n
    latest_arrival[n-1] = s
    
    # BFS with at most n iterations
    for iteration in range(n):
        updated = False
        for line in lines:
            u, v, t0, p, d = line
            # Check if we can use this line in reverse (v -> u)
            if latest_arrival[v] != -1:
                # We need to arrive at v by latest_arrival[v]
                # So departure from u must be: depart + d <= latest_arrival[v]
                # depart <= latest_arrival[v] - d
                target_depart = latest_arrival[v] - d
                if target_depart >= t0:
                    # Find latest k such that t0 + k*p <= target_depart
                    k = (target_depart - t0) // p
                    depart_time = t0 + k * p
                    arrive_at_u = depart_time + d  # This is actually depart_time from u, but for reverse thinking
                    # Actually, we arrive at u at depart_time (we depart u at depart_time, arrive v at depart_time + d)
                    # For reverse: we arrive at v at latest_arrival[v], so we must depart u at depart_time
                    # Latest we can depart u is depart_time
                    if latest_arrival[u] < depart_time:
                        latest_arrival[u] = depart_time
                        updated = True
        if not updated:
            break
    
    return latest_arrival[0]

@cocotb.test()
async def test_tram_scheduling(dut):
    """Test tram scheduling with various cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.s.value = 0
    dut.num_stops.value = 0
    dut.num_lines.value = 0
    for i in range(8):
        dut.t0[i].value = 0
        dut.p[i].value = 0
        dut.d[i].value = 0
        dut.u[i].value = 0
        dut.v[i].value = 0
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # Case 1: Simple valid case
        {
            's': 10,
            'n': 2,
            'm': 1,
            'lines': [(0, 1, 1, 2, 6)],
            'expected': 3,
            'should_work': True
        },
        # Case 2: Impossible
        {
            's': 5,
            'n': 2,
            'm': 1,
            'lines': [(0, 1, 1, 1, 5)],
            'expected': None,
            'should_work': False
        },
        # Case 3: Multiple lines
        {
            's': 20,
            'n': 3,
            'm': 2,
            'lines': [(0, 1, 0, 5, 5), (1, 2, 2, 5, 8)],
            'expected': 7,
            'should_work': True
        },
        # Case 4: Direct connection with period
        {
            's': 100,
            'n': 2,
            'm': 1,
            'lines': [(0, 1, 0, 30, 20)],
            'expected': 70,
            'should_work': True
        },
        # Case 5: Need to wait for tram
        {
            's': 15,
            'n': 2,
            'm': 1,
            'lines': [(0, 1, 10, 5, 3)],
            'expected': 12,
            'should_work': True
        }
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, tc in enumerate(test_cases):
        print(f"
Test case {i+1}: {tc['s']} {tc['n']} {tc['m']}")
        
        # Configure inputs
        dut.s.value = tc['s']
        dut.num_stops.value = tc['n']
        dut.num_lines.value = tc['m']
        
        # Clear all line inputs first
        for j in range(8):
            dut.t0[j].value = 0
            dut.p[j].value = 0
            dut.d[j].value = 0
            dut.u[j].value = 0
            dut.v[j].value = 0
        
        # Set line data
        for j, (u, v, t0, p, d) in enumerate(tc['lines']):
            dut.u[j].value = u
            dut.v[j].value = v
            dut.t0[j].value = t0
            dut.p[j].value = p
            dut.d[j].value = d
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (max 100 cycles to be safe)
        done = False
        for _ in range(100):
            await RisingEdge(dut.clk)
            if dut.valid.value or dut.impossible.value:
                done = True
                break
        
        if not done:
            print(f"  ERROR: Computation did not complete")
            continue
        
        # Check results
        if tc['should_work']:
            if dut.impossible.value:
                print(f"  ERROR: Expected result {tc['expected']}, got impossible")
            else:
                result = int(dut.latest_departure.value)
                expected = tc['expected']
                if result == expected:
                    print(f"  PASS: Got {result} (expected {expected})")
                    passed += 1
                else:
                    print(f"  ERROR: Got {result}, expected {expected}")
        else:
            if dut.impossible.value:
                print(f"  PASS: Correctly detected impossible")
                passed += 1
            else:
                result = int(dut.latest_departure.value)
                print(f"  ERROR: Expected impossible, got {result}")
    
    print(f"
{passed}/{total} tests passed")
    if passed < total:
        raise TestFailure(f"Only {passed}/{total} tests passed")