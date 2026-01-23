import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random
import math

@cocotb.test()
async def test_burger_solver(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n_in.value = 0
    dut.k_in.value = 0
    dut.a_in.value = 0
    dut.b_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases (scaled down to fit constraints N*K <= 1024)
    # Format: (n, k, a, b)
    test_cases = [
        (2, 3, 1, 1),   # From example 1 (Original 2,3)
        (3, 2, 0, 0),   # From example 2 (Original 3,2)
        (1, 10, 5, 3),  # From example 3 (Original 1,10) -> S=10
        (3, 3, 1, 0),   # Custom
        (4, 5, 1, 2),   # Custom
        (5, 5, 2, 2),   # Custom
    ]

    for n, k, a, b in test_cases:
        # Python reference calculation
        S = n * k
        min_stops = float('inf')
        max_stops = 0
        
        # Iterate all i
        for i in range(n):
            # Base position of restaurant i
            rest_pos = i * k
            
            # 4 variations of step construction
            # We compute step L which is (target_pos - start_pos) mod S
            # Start position is relative to a restaurant. Target is relative to another restaurant.
            # Let's use the 4 formulas derived from the math solutions:
            # s1 = (i*k + b - a)
            # s2 = (i*k + b + a)
            # s3 = (i*k - b - a)
            # s4 = (i*k - b + a)
            
            for base_step in [rest_pos + b - a, rest_pos + b + a, rest_pos - b - a, rest_pos - b + a]:
                # Calculate L for GCD
                L = base_step % S
                # If L is 0, it means we return to start immediately in 1 stop (or return to start after 1 step which is the stop itself? Problem says stops excluding first.)
                # If L=0, gcd(S,0)=S, stops = S/S = 1. Correct.
                # If L != 0, stops = S / gcd(S, L)
                
                if L == 0:
                    stops = 1
                else:
                    stops = S // math.gcd(S, L)
                
                min_stops = min(min_stops, stops)
                max_stops = max(max_stops, stops)
        
        # Drive DUT
        dut.n_in.value = n
        dut.k_in.value = k
        dut.a_in.value = a
        dut.b_in.value = b
        
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 10000
        cycles = 0
        while dut.done.value == 0:
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > timeout:
                raise TestFailure(f"Test case (n={n}, k={k}) timed out")
        
        # Check results
        dut_min = int(dut.min_stops.value)
        dut_max = int(dut.max_stops.value)
        
        if dut_min != min_stops:
            raise TestFailure(f"Case (n={n}, k={k}, a={a}, b={b}): Min mismatch. Ref: {min_stops}, DUT: {dut_min}")
        if dut_max != max_stops:
            raise TestFailure(f"Case (n={n}, k={k}, a={a}, b={b}): Max mismatch. Ref: {max_stops}, DUT: {dut_max}")
            
        print(f"Test passed for n={n}, k={k}, a={a}, b={b}: Min={dut_min}, Max={dut_max}")
