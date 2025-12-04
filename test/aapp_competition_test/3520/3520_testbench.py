import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from fixed_point import fixbv  # Assume fixbv available (Q16.16 format)

@cocotb.test()
async def test_pill_scheduler(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (values in Q16.16 format)
    test_cases = [
        { # Sample Input 1
            "n": fixbv(100.0, min=-2**31, max=2**31-1, res=2**-16).int(),
            "c": fixbv(10.0, min=-2**31, max=2**31-1, res=2**-16).int(),
            "pills": [
                (15.0, 99.0, 98.0), # t=15, x=99, y=98
                (40.0, 3.0, 2.0), # t=40, x=3, y=2
                (90.0, 10.0, 9.0), # t=90, x=10, y=9
                (9999.0, 1.0, 1.0) # unused
            ],
            "expected": fixbv(115.0, min=-2**31, max=2**31-1, res=2**-16).int()
        }
    ]
    
    passed = 0
    for case in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        dut.n.value = case["n"]
        dut.c.value = case["c"]
        dut.pill1_t.value = fixbv(case["pills"][0][0], min=-2**31, max=2**31-1, res=2**-16).int()
        dut.pill1_x.value = fixbv(case["pills"][0][1], min=-2**31, max=2**31-1, res=2**-16).int()
        dut.pill1_y.value = fixbv(case["pills"][0][2], min=-2**31, max=2**31-1, res=2**-16).int()
        dut.pill2_t.value = fixbv(case["pills"][1][0], min=-2**31, max=2**31-1, res=2**-16).int()
        dut.pill2_x.value = fixbv(case["pills"][1][1], min=-2**31, max=2**31-1, res=2**-16).int()
        dut.pill2_y.value = fixbv(case["pills"][1][2], min=-2**31, max=2**31-1, res=2**-16).int()
        dut.pill3_t.value = fixbv(case["pills"][2][0], min=-2**31, max=2**31-1, res=2**-16).int()
        dut.pill3_x.value = fixbv(case["pills"][2][1], min=-2**31, max=2**31-1, res=2**-16).int()
        dut.pill3_y.value = fixbv(case["pills"][2][2], min=-2**31, max=2**31-1, res=2**-16).int()
        dut.pill4_t.value = fixbv(case["pills"][3][0], min=-2**31, max=2**31-1, res=2**-16).int()
        dut.pill4_x.value = fixbv(case["pills"][3][1], min=-2**31, max=2**31-1, res=2**-16).int()
        dut.pill4_y.value = fixbv(case["pills"][3][2], min=-2**31, max=2**31-1, res=2**-16).int()
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (16 cycles)
        for _ in range(20):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Verify output
        expected = case["expected"]
        actual = dut.max_lifespan.value.integer
        
        # Allow 1 unit tolerance in fixed-point representation
        if abs(actual - expected) <= 1:
            passed += 1
        else:
            actual_float = fixbv(actual, min=-2**31, max=2**31-1, res=2**-16).f
            expected_float = fixbv(expected, min=-2**31, max=2**31-1, res=2**-16).f
            dut._log.error(f"Test failed: Got {actual_float:.6f}, expected {expected_float:.6f}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
