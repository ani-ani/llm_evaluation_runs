import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_negabase_converter(dut):
    """Test the negabase converter module"""
    
    # Create a clock (50MHz)
    clock = Clock(dut.clk, 20, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.p.value = 0
    dut.k.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (p, k, expected_coeffs)
    # 46 2 -> 0 1 0 0 1 1 1
    # 2018 214 -> 92 205 1
    # 4 2 -> 0 0 1
    # 1 2 -> 1
    test_cases = [
        (46, 2, [0, 1, 0, 0, 1, 1, 1]),
        (2018, 214, [92, 205, 1]),
        (4, 2, [0, 0, 1]),
        (1, 2, [1]),
        (10, 3, [1, 0, 1]), # 10 -> 101 in -3 base
    ]
    
    passed = 0
    total = len(test_cases)
    
    for p, k, expected in test_cases:
        dut._log.info(f"Testing p={p}, k={k}")
        
        # Start
        dut.p.value = p
        dut.k.value = k
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for processing to complete (go to output state)
        # Max cycles for 64 bits is ~64 for math + overhead
        max_cycles = 100
        
        # Wait until done is high (or we see transition to output)
        # We actually need to wait for the OUTPUT phase to finish streaming
        # The module specification implies 'done' goes high when all is done.
        # But we also need to read coefficients.
        
        # Let's wait for 'done' to be high, but check output while it's low if streaming
        # Or wait for done to be high, then check history if internal.
        # The prompt says 'coeff_out' is valid when done or during output.
        # Let's assume 'done' goes high AFTER outputting the last coefficient.
        
        # However, a more common pattern is: done is high when ready for next, or done pulses.
        # Let's assume 'done' stays high after computation. 
        # If the module streams out while processing, we need to capture values.
        # Given 'done' is an output, let's wait for it to go high.
        # But if it streams out one per cycle, we need to check every cycle.
        
        # Let's assume the module streams coefficients to coeff_out every cycle during output.
        # We will sample coeff_out every cycle until done goes high.
        
        observed_coeffs = []
        
        for _ in range(max_cycles):
            await RisingEdge(dut.clk)
            
            # Check if done is asserted (assuming it stays high after finish)
            # If the module outputs coefficients while processing, we check coeff_out now
            if dut.done.value == 1:
                # We might have missed the last coeff if done goes high after it was valid
                # Let's check coeff_out now too
                if len(observed_coeffs) < len(expected):
                     observed_coeffs.append(int(dut.coeff_out.value))
                break
            
            # If not done, and we are in output phase (count > 0 implies output happened)
            # But the prompt says 'coeff_out' is valid when done or during output.
            # Let's capture coeff_out if count is incrementing or if it's stable.
            # Let's just capture every cycle where coeff_out changes or count increments.
            # A simpler approach: capture any non-zero coeff_out or if count > 0.
            
            # We will just append everything we see to a list until done.
            # But we need to know when a new coefficient is valid.
            # Usually, there's a 'valid' signal, but here there isn't explicitly.
            # 'count' increments as coefficients are generated.
            
            # Let's look at the 'count' signal. If it increments, we save the previous coeff.
            # Or simpler: just save coeff_out every cycle if it's not the same as last or if count changed.
            
            # Actually, let's just save coeff_out every cycle until done is high.
            # But that will duplicate values if the module holds the value.
            # Let's assume the module streams: valid for 1 cycle.
            # We will check if count increased.
            
            # Let's rely on the prompt: "Result valid X clock cycles after start" implies sequential output.
            # We will just capture coeff_out whenever count > observed_count.
            
            current_count = int(dut.count.value)
            if current_count > len(observed_coeffs) and len(observed_coeffs) < len(expected):
                 observed_coeffs.append(int(dut.coeff_out.value))
        
        # Wait a bit more if done hasn't triggered yet
        if dut.done.value == 0:
             await Timer(100, units='ns')
             if dut.done.value == 0:
                 raise TestFailure(f"Done not asserted for p={p} k={k}")

        # Final capture if we missed the last one
        if len(observed_coeffs) < len(expected):
            observed_coeffs.append(int(dut.coeff_out.value))

        if len(observed_coeffs) != len(expected):
             raise TestFailure(f"Length mismatch for p={p}, k={k}. Expected {len(expected)}, got {len(observed_coeffs)}")
        
        if observed_coeffs != expected:
             raise TestFailure(f"Coeff mismatch for p={p}, k={k}. Expected {expected}, got {observed_coeffs}")
            
        passed += 1
        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{total} tests passed")
