import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

MOD = 1000000007

def mod_inv(a):
    return pow(a, MOD - 2, MOD)

# Precomputed inverses
INV_LEN = {1: 1, 2: 500000004, 3: 333333336, 4: 250000002, 5: 400000003, 6: 166666668, 7: 142857144, 8: 125000001}

class PokenomTester:
    def __init__(self, dut):
        self.dut = dut
        self.dut.rst_n.value = 1
        self.dut.start.value = 0
        self.dut.query_type.value = 0
        self.dut.u.value = 0
        self.dut.v.value = 0
        # Expected state
        self.E = [0] * 9  # 1-based indexing
        self.E2 = [0] * 9

    async def reset(self):
        self.dut.rst_n.value = 0
        await Timer(10, units='ns')
        self.dut.rst_n.value = 1
        await Timer(10, units='ns')
        self.E = [0] * 9
        self.E2 = [0] * 9

    async def send_add_query(self, u, v):
        # Update reference model
        length = v - u + 1
        inv = INV_LEN[length]
        
        # We must use old E values for E2 calculation
        old_E = self.E[u:v+1]
        
        for i in range(u, v + 1):
            old_val = self.E[i]
            self.E[i] = (self.E[i] + inv) % MOD
            self.E2[i] = (self.E2[i] + 2 * old_val + inv) % MOD
        
        # Send to DUT
        self.dut.query_type.value = 1
        self.dut.u.value = u
        self.dut.v.value = v
        await RisingEdge(self.dut.clk)
        self.dut.start.value = 1
        await RisingEdge(self.dut.clk)
        self.dut.start.value = 0
        
        # Wait for done
        while not self.dut.done.value:
            await RisingEdge(self.dut.clk)
        
        await RisingEdge(self.dut.clk)

    async def send_calc_query(self):
        # Calculate expected sum
        expected_sum = 0
        for i in range(1, 9):
            expected_sum = (expected_sum + self.E2[i]) % MOD
        
        # Send to DUT
        self.dut.query_type.value = 2
        await RisingEdge(self.dut.clk)
        self.dut.start.value = 1
        await RisingEdge(self.dut.clk)
        self.dut.start.value = 0
        
        # Wait for done
        while not self.dut.done.value:
            await RisingEdge(self.dut.clk)
        
        # Check result
        dut_result = int(self.dut.result.value)
        if dut_result != expected_sum:
            raise TestFailure(f"Mismatch! Expected {expected_sum}, Got {dut_result}")
        
        print(f"Calc query passed. Result: {dut_result}")
        await RisingEdge(self.dut.clk)

@cocotb.test()
async def test_pokenom_basic(dut):
    """Test basic functionality with simple sequence"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    tester = PokenomTester(dut)
    await tester.reset()
    
    # Test Case 1: 1 1 2
    # Box 1 and 2 get +0.5 expected
    await tester.send_add_query(1, 2)
    
    # Calculate
    await tester.send_calc_query()
    
    # Test Case 2: 1 1 2 again
    # Now E[1] = 0.5 + 0.5 = 1.0
    # E2[1] = 0.5 + 2*0.5 + 0.5 = 2.0
    # Same for box 2
    # Sum = 4.0
    await tester.send_add_query(1, 2)
    await tester.send_calc_query()
    
    print("All tests passed!")

@cocotb.test()
async def test_pokenom_example_2(dut):
    """Test with range 1-3"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    tester = PokenomTester(dut)
    await tester.reset()
    
    # Query 1: 1 1 3 (len=3, inv=333333336)
    await tester.send_add_query(1, 3)
    await tester.send_calc_query()
    
    # Query 2: 1 1 3
    # Expected final sum should be 8/3 = 2.666... = 666666674 mod M
    await tester.send_add_query(1, 3)
    await tester.send_calc_query()
    
    print("Example 2 tests passed!")
