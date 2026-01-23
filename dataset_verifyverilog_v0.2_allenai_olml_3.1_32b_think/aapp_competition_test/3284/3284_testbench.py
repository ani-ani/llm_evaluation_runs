import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

# Helper function to compute GCD in Python
def gcd(a, b):
    while b:
        a, b = b, a % b
    return a

def count_coprime_pairs(a, b, c, d):
    count = 0
    for x in range(a, b + 1):
        for y in range(c, d + 1):
            if gcd(x, y) == 1:
                count += 1
    return count

@cocotb.test()
async def test_coprime_counter(dut):
    """Test coprime counter module"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.a.value = 0
    dut.b.value = 0
    dut.c.value = 0
    dut.d.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    # Using small ranges to fit within reasonable simulation time
    # Scale down original test cases to fit small range constraint (1-8)
    test_cases = [
        (1, 5, 1, 5),   # Expected: 19
        (1, 4, 1, 4),   # Expected: ? Let's calculate: 1,2,3,4. 
                        # 1: 1,2,3,4 (4)
                        # 2: 1(1),2(2),3(1),4(2) -> 1,3 (2)
                        # 3: 1(1),2(1),3(3),4(1) -> 1,2,4 (3)
                        # 4: 1(1),2(2),3(1),4(4) -> 1,3 (2)
                        # Total: 4+2+3+2 = 11
        (2, 4, 2, 4),   # Expected: 3 (2,3; 3,2; 3,4; 4,3 -> 2,3 and 3,2 and 3,4 and 4,3 -> wait: 
                        # 2:2,3,4 -> 3 (1) -> 2
                        # 3:2,3,4 -> 2,4 (2) -> 2
                        # 4:2,3,4 -> 3 (1) -> 2
                        # Total 2+2+2=6? No. 
                        # 2(2) -> 3(1) -> gcd=1, 4(2) -> gcd=2
                        # 3(3) -> 2(1), 4(1) -> gcd=1
                        # 4(4) -> 2(2), 3(1) -> gcd=1
                        # Pairs: (2,3), (3,2), (3,4), (4,3). Total 4.
                        # Wait, check (2,3)=1, (3,2)=1, (3,4)=1, (4,3)=1. Correct 4.
        (5, 5, 5, 5),   # (5,5) gcd=5 -> 0
        (5, 5, 6, 6),   # (5,6) gcd=1 -> 1
    ]
    
    # Since the module assumes max range 8, we use these small tests.
    # Let's calculate expected values precisely for these ranges.
    # 1. (1,5,1,5) -> 19
    # 2. (1,4,1,4) -> 
    #   x=1: y=1,2,3,4 -> gcd=1 -> 4
    #   x=2: y=1(1), 2(2), 3(1), 4(2) -> 1,3 -> 2
    #   x=3: y=1(1), 2(1), 3(3), 4(1) -> 1,2,4 -> 3
    #   x=4: y=1(1), 2(2), 3(1), 4(4) -> 1,3 -> 2
    #   Total: 4+2+3+2 = 11
    # 3. (1,3,1,3)
    #   x=1: 1,2,3 -> 3
    #   x=2: 1,3 -> 2
    #   x=3: 1,2 -> 2
    #   Total: 7
    # 4. (2,5,2,5) -> 
    #   x=2: y=3 -> 1
    #   x=3: y=2,4,5 -> 3 (wait gcd(3,4)=1, gcd(3,5)=1) -> 2,4,5 -> 3
    #   x=4: y=3,5 -> 2
    #   x=5: y=2,3,4 -> 3 (gcd(5,2)=1, gcd(5,3)=1, gcd(5,4)=1) -> 3
    #   Total: 1+3+2+3 = 9
    
    adapted_cases = [
        (1, 5, 1, 5, 19),
        (1, 4, 1, 4, 11),
        (1, 3, 1, 3, 7),
        (2, 5, 2, 5, 9)
    ]
    
    for a, b, c, d, expected in adapted_cases:
        dut.a.value = a
        dut.b.value = b
        dut.c.value = c
        dut.d.value = d
        
        # Start signal
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 2000 # Safety timeout
        cycles = 0
        while dut.done.value == 0 and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
            
        if cycles >= timeout:
            dut._log.error(f"Timeout for case {a},{b},{c},{d}")
            assert False
            
        actual = int(dut.result.value)
        dut._log.info(f"Range [{a},{b}] x [{c},{d}]: Expected {expected}, Got {actual}")
        assert actual == expected, f"Mismatch: Expected {expected}, Got {actual}"
        
        # Small delay before next test
        await Timer(10, units='ns')
        
    dut._log.info("All tests passed!")
