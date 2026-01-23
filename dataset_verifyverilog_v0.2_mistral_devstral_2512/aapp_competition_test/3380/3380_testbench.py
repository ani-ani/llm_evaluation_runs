import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_probability_calculator(dut):
    """Test the probability calculator for N=2 and N=4"""
    
    # Create a clock with a 10ns period
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
    
    # Expected results in Q16.16
    # N=2: 1.0 = 0x00010000 (65536)
    # N=4: 26/27 ≈ 0.96296296.
    # 0.96296296 * 65536 = 63108.74
    # Integer division (26 << 16) / 27 = 1703936 / 27 = 63108
    # Let's check what the DUT produces. If it uses integer division, it will be 63108.
    # If it rounds, 63109.
    # We will verify it is close to 63108.
    
    test_cases = [
        (2, 65536),   # 1.0
        (4, 63108),   # 26/27 approx (integer division)
        (4, 63109),   # Also accept rounding
        (5, 0)        # Unsupported N
    ]
    
    for n, expected in test_cases:
        # Start transaction
        dut.N.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (based on 4 cycle latency)
        # We need to wait until done is high.
        # The state machine takes 4 cycles.
        # Let's wait for the done signal.
        
        cycles_waited = 0
        while dut.done.value == 0 and cycles_waited < 10:
            await RisingEdge(dut.clk)
            cycles_waited += 1
            
        # Check result
        # The prompt says "Result valid X clock cycles after start"
        # With a state machine, 'done' signals validity.
        
        if dut.done.value == 1:
            actual = int(dut.result.value)
            if n == 2:
                assert actual == expected, f"N={n}: Expected {expected}, got {actual}"
            elif n == 4:
                # Allow small error for division or rounding
                assert (actual == 63108 or actual == 63109), f"N={n}: Expected 63108 or 63109, got {actual}"
            elif n == 5:
                assert actual == 0, f"N={n}: Expected 0, got {actual}"
            print(f"Test passed for N={n}. Result: {actual}")
        else:
            cocotb.log.error(f"Done not asserted for N={n}")
            assert False, "Done not asserted"
            
    print("All tests completed successfully")
