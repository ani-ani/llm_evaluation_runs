import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_airline_scheduler(dut):
    """Test the airline scheduler module with multiple test cases"""
    
    # Create clock (10ns period = 100MHz)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.m.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define Test Cases (Scaled)
    # Case 1: 2 airports, 2 flights. Flight 1->2 at t=1. Flight 2->1 at t=1. 
    # Flight 1->2 arrives at t=1+flight(1,2)+inspection(2). 
    # Flight 2->1 arrives at t=1+flight(2,1)+inspection(1).
    # If these overlap, need 2 planes. 
    # Inputs: inspection_times=[1,1], flight_times=[[0,1],[1,0]]
    # Flight 0: 0->1, dep=1. Flight 1: 1->0, dep=1.
    # Transition 0->1: Arrival = 1 + flight(1,2) [from dest 1 to src 2] + inspect(src 2). Wait, flight 0 dest is 1. 
    # Flight 0 is from 0 to 1. Dest is 1. 
    # Flight 1 is from 1 to 0. Src is 1.
    # Transition 0->1: Plane finishes flight 0 at dest 1. Must fly back to src of flight 1 (airport 1). Flight 0 dest is 1, Flight 1 src is 1. 
    # Time taken: flight(1,1) + inspect(1). 
    # Transition 1->0: Plane finishes flight 1 at dest 0. Must fly to src of flight 0 (airport 0). 
    # If times are tight, might need 2 planes.
    # Let's use the example provided logic.
    
    # Case 1 inputs
    # n=2, m=2
    # inspection = [1, 1]
    # flight_times = [[0, 1], [1, 0]]
    # flights: 1->2 dep 1 (0->1 dep 1), 2->1 dep 1 (1->0 dep 1)
    # Let's scale inputs. The problem says flight time from i to j.
    # Flight 1: s=1, f=2, t=1. (Indices 0,1)
    # Flight 2: s=2, f=1, t=1. (Indices 1,0)
    # Transition 1->2: Plane finishes 1 at dest 2 (index 1). Needs to be at src 2 (index 1) for flight 2. 
    # Dest 1 = Src 1. Flight time 0. Inspect 1 (value 1). Arrival = 1 + 0 + 1 = 2.
    # Flight 2 departs at 1. 2 > 1. Cannot connect.
    # Case 1 Result: 2 planes.
    
    # Case 2 inputs
    # Flight 1->2 dep 1. Flight 2->1 dep 3.
    # Transition 1->2: Arrival = 1 + 0 + 1 = 2. 
    # Flight 2 dep 3. 2 <= 3. Can connect.
    # Case 2 Result: 1 plane.
    
    # Case 3 inputs (from sample)
    # n=5, m=5. Scaled down to n=4, m=4 to fit Verilog constraints.
    # Let's define a smaller test case compatible with 4 nodes/edges.
    # Test Case 3: n=3, m=3.
    # Inspection: [10, 20, 30]
    # Flight Times:
    # 0->1: 5, 0->2: 10
    # 1->0: 15, 1->2: 5
    # 2->0: 10, 2->1: 5
    # Flights:
    # F0: 0->1, dep 100
    # F1: 1->2, dep 115 (Gap = flight(1,1)+inspect(1)=0+20=20. 100+flight(0,1)=105 arrival. Time to prep for F1: 115-105=10. Inspect(1)=20. Need 20. < 10? No. Wait. 
    # F0 arrives at F0 dest=1. Plane at airport 1. F1 src=1. 
    # Time to be ready for F1: F0_arrival + inspection(1) = 105 + 20 = 125.
    # F1 dep 115. 125 > 115. No link.
    # 
    # Let's try:
    # F0: 0->1 dep 100. Arrival 100+5=105. Ready 125.
    # F1: 1->2 dep 130. Gap = 130-100=30. Flight 0->1=5. Prep 20. Total 25. OK.
    # F2: 2->0 dep 140. From F1. Arrival F1: 130+5=135. Ready 135+30=165. F2 dep 140. Fail.
    # 
    # Let's try cyclic chain: F0->F1->F2->F0?
    # F0: 0->1 dep 100
    # F1: 1->2 dep 120 (100 + flight(0,1)=105 + inspect(1)=20 = 125. Too late. 120 is too early.)
    # Let's adjust:
    # F0: 0->1 dep 100. Ready 125.
    # F1: 1->2 dep 130. Arrival 135. Ready 165.
    # F2: 2->0 dep 170. Arrival 170+10=180. Ready 180+30=210.
    # 
    # Let's use the provided samples but scaled to 4x4 max.
    # Sample 1 -> N=2, M=2. (Fits)
    # Sample 2 -> N=2, M=2. (Fits)
    # We need 3 test cases.
    # Test 3: N=3, M=3.
    # Inspection: [1, 1, 1]
    # Flight Times: All 1 (except 0).
    # F0: 0->1 dep 10
    # F1: 1->2 dep 12 (10+1+1=12 exact match)
    # F2: 2->0 dep 14 (12+1+1=14 exact match)
    # Result: 1 plane.
    
    test_cases = [
        # Case 1: 2 planes needed
        {
            'n': 2, 'm': 2,
            'inspection': [1, 1],
            'flight_times': [[0, 1], [1, 0]],
            'flights': [
                [0, 1, 1], # 1->2 dep 1
                [1, 0, 1]  # 2->1 dep 1
            ],
            'expected': 2
        },
        # Case 2: 1 plane needed
        {
            'n': 2, 'm': 2,
            'inspection': [1, 1],
            'flight_times': [[0, 1], [1, 0]],
            'flights': [
                [0, 1, 1], # 1->2 dep 1
                [1, 0, 3]  # 2->1 dep 3
            ],
            'expected': 1
        },
        # Case 3: 1 plane needed (cyclic)
        {
            'n': 3, 'm': 3,
            'inspection': [1, 1, 1],
            'flight_times': [[0, 1, 1], [1, 0, 1], [1, 1, 0]], # Symmetric times
            'flights': [
                [0, 1, 10], # 1->2 dep 10
                [1, 2, 12], # 2->3 dep 12 (arr 11+1(inspect)=12)
                [2, 0, 14]  # 3->1 dep 14 (arr 13+1=14)
            ],
            'expected': 1
        }
    ]

    for i, tc in enumerate(test_cases):
        dut._log.info(f"Running Test Case {i+1}: Expected {tc['expected']}")
        
        # Load n and m
        dut.n.value = tc['n']
        dut.m.value = tc['m']
        
        # Load Inspection Times (pad to 4)
        for k in range(4):
            val = tc['inspection'][k] if k < tc['n'] else 0
            dut.inspection_times[k].value = val
            
        # Load Flight Times (4x4 matrix)
        for r in range(4):
            for c in range(4):
                val = 0
                if r < tc['n'] and c < tc['n']:
                    val = tc['flight_times'][r][c]
                dut.flight_times[r][c].value = val
                
        # Load Flight Reqs (source, dest, time)
        for k in range(4):
            if k < tc['m']:
                # Input format: [source, dest, time]
                dut.flight_reqs[k][0].value = tc['flights'][k][0]
                dut.flight_reqs[k][1].value = tc['flights'][k][1]
                dut.flight_reqs[k][2].value = tc['flights'][k][2]
            else:
                dut.flight_reqs[k][0].value = 0
                dut.flight_reqs[k][1].value = 0
                dut.flight_reqs[k][2].value = 0

        # Start
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 200
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Test case {i+1} timed out")
            
        # Check result
        actual = int(dut.result.value)
        if actual != tc['expected']:
            raise TestFailure(f"Test case {i+1} failed: Expected {tc['expected']}, got {actual}")
        
        dut._log.info(f"Test Case {i+1} Passed: {actual}")
        
    dut._log.info("All 3 tests passed!")
