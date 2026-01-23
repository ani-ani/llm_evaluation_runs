import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure, TestSuccess

@cocotb.test()
async def test_minimal_unique_substring_gen(dut):
    """Test the minimal_unique_substring_gen module"""
    
    # Start the clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset the DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.k.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases: (n, k, expected_string)
    test_cases = [
        (4, 4, "1111"),
        (5, 3, "01010"),
        (7, 3, "0010010"),
        (1, 1, "1"),
        (3, 1, "010"),
        (4, 2, "0101"),
        (2, 2, "11")
    ]
    
    for n, k, expected in test_cases:
        dut._log.info(f"Testing n={n}, k={k}")
        
        # Set inputs
        dut.n.value = n
        dut.k.value = k
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Collect output bits
        output_bits = []
        bits_collected = 0
        
        while bits_collected < n:
            await RisingEdge(dut.clk)
            # Check done flag
            if dut.done.value == 1 and bits_collected < n:
                # If done is asserted early, we might stop or just collect what we have
                # Based on spec, done is high when n bits generated.
                pass
            
            # Capture the bit
            if bits_collected < n:
                output_bits.append(str(int(dut.out_bit.value)))
                bits_collected += 1
        
        generated = "".join(output_bits)
        
        if generated != expected:
            raise TestFailure(f"Mismatch for n={n}, k={k}: expected '{expected}', got '{generated}'")
        else:
            dut._log.info(f"Pass: Generated '{generated}'")

    dut._log.info("All tests passed!")
