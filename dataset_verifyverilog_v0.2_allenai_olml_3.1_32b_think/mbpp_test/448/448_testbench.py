import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def test_perrin_sum(dut):
    # Create a clock with a period of 10ns
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset the DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.N.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Helper function to run a test case
    async def run_test(N_val, expected_sum):
        dut.N.value = N_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done to go high
        timeout_count = 0
        while not dut.done.value and timeout_count < 50:
            await RisingEdge(dut.clk)
            timeout_count += 1
        
        assert dut.done.value == 1, "Done signal did not go high"
        assert dut.result.value == expected_sum, f"For N={N_val}, expected {expected_sum}, got {dut.result.value}"
        print(f"Test passed: N={N_val}, Sum={dut.result.value}")

        # Wait a bit before next test
        await RisingEdge(dut.clk)

    # Test Cases
    # Perrin Sequence: 3, 0, 2, 3, 2, 5, 5, 7, 10, 12, 17, 22, ...
    # Sums:
    # N=0: 3
    # N=1: 3+0 = 3
    # N=2: 3+0+2 = 5
    # N=3: 3+0+2+3 = 8
    # N=4: 3+0+2+3+2 = 10
    # N=5: 3+0+2+3+2+5 = 15
    # N=9: (Given expected 49 in prompt, let's verify) 
    #   3+0+2+3+2+5+5+7+10+12 = 49 (Wait, prompt says cal_sum(9) == 49. Let's check the sequence logic again.)
    #   Prompt sequence generation: a=3, b=0, c=2. Sum starts at 5 (for n=2). Loop n>2.
    #   n=9. Loop from 2 to 9. iterations = 7.
    #   Let's trace: sum=5 (3+0+2). 
    #   3: d=3+0=3, sum=8. (a=0, b=2, c=3)
    #   4: d=0+2=2, sum=10. (a=2, b=3, c=2)
    #   5: d=2+3=5, sum=15. (a=3, b=2, c=5)
    #   6: d=3+2=5, sum=20. (a=2, b=5, c=5)
    #   7: d=2+5=7, sum=27. (a=5, b=5, c=7)
    #   8: d=5+5=10, sum=37. (a=5, b=7, c=10)
    #   9: d=5+7=12, sum=49. 
    #   Yes, the prompt's expected values are correct for the logic provided.

    print("Starting tests...")
    await run_test(0, 3)
    await run_test(1, 3)
    await run_test(2, 5)
    await run_test(9, 49)
    await run_test(10, 66)
    await run_test(11, 88)
    
    # Edge case: N=15 (max for 4-bit counter logic if N<=15, prompt says N up to 16, input is 5 bits, counter needs to handle up to N)
    # Let's calculate sum(15) manually to verify our testbench logic is robust.
    # 3,0,2,3,2,5,5,7,10,12,17,22,29,39,51,68
    # Sum(15) = Sum(11) + 29 + 39 + 51 + 68 = 88 + 187 = 275
    await run_test(15, 275)
