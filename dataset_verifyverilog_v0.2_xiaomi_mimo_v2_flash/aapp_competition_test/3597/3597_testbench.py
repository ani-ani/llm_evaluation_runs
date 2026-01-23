import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import math

@cocotb.test()
async def test_pool_shark(dut):
    """Test the Pool Shark solver"""
    
    # Helper to convert float to Q16.16
    def to_q16_16(val):
        return int(val * 65536) & 0xFFFFFFFF

    # Helper to convert Q16.16 to float
    def to_float(val):
        if val & 0x80000000: # Sign bit
            return -((0x100000000 - val) / 65536.0)
        return val / 65536.0

    # Helper to send inputs
    async def send_inputs(w, l, r, x1, y1, x2, y2, x3, y3, h):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        inputs = [w, l, r, x1, y1, x2, y2, x3, y3, h]
        # Pack 2 inputs per cycle
        for i in range(0, len(inputs), 2):
            # Ensure we don't write beyond available inputs (data_valid)
            # In this simplified model, we assume data_valid[0] is always high for the input sequence
            dut.data_valid.value = 0b11 if i + 1 < len(inputs) else 0b01
            
            # Convert to Q16.16
            val1 = to_q16_16(inputs[i])
            val2 = to_q16_16(inputs[i+1]) if i+1 < len(inputs) else 0
            
            # In a real packed scenario, we might combine them. 
            # Here we assume the DUT handles `data_in` as a 16-bit slice of the input stream.
            # To match the spec: `input [15:0] data_in`. 
            # The spec says "Passed 2 per cycle for area optimization" but has 16-bit input.
            # This implies maybe parallel inputs or a sequence. 
            # The testbench will feed them sequentially.
            # Let's assume the DUT captures `data_in` into a buffer when `data_valid[0]` is high.
            # But to simplify, let's just feed one value per cycle if the spec is ambiguous.
            # The prompt said "Passed 2 per cycle", but inputs are 16-bit. 
            # Let's just feed one value per cycle for simplicity of testbench.
            # We will set data_valid = 1 and send values one by one.
            
            # Actually, let's follow the prompt's "2 per cycle" hint.
            # But since `data_in` is 16-bit, we can't send 2 values at once unless packed.
            # Let's assume the prompt meant 2 values over 2 cycles or packed.
            # To be safe and generic for LLM generation, let's feed one value per cycle.
            # We set data_valid = 1 for the first 10 cycles.
            
            dut.data_valid.value = 1
            dut.data_in.value = val1
            await RisingEdge(dut.clk)
            
            if i + 1 < len(inputs):
                dut.data_in.value = val2
                await RisingEdge(dut.clk)
        
        dut.data_valid.value = 0

    # Setup Clock
    clock = Clock(dut.clk, 10, units='ns')
    clock.start

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in.value = 0
    dut.data_valid.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # --- Test Case 1: Possible (from example) ---
    # Input: 20 30
    # 2 10 20 2 24 18 28 10
    # w=20, l=30, r=2, x1=10, y1=20, x2=2, y2=24, x3=18, y3=28, h=10
    # Expected: 12.74 127.83
    
    await send_inputs(20, 30, 2, 10, 20, 2, 24, 18, 28, 10)
    
    # Wait for computation. The state machine will take time.
    # We loop until done or timeout.
    timeout = 0
    while not dut.done.value and not dut.impossible.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if dut.impossible.value:
        raise TestFailure("Test Case 1 failed: Reported impossible")
    if not dut.done.value:
        raise TestFailure("Test Case 1 failed: Timeout")
        
    d_out = to_float(dut.d_out.value)
    theta_out = to_float(dut.theta_out.value)
    
    # Allow some error margin for hardware approximation
    if abs(d_out - 12.74) > 0.1 or abs(theta_out - 127.83) > 0.1:
        print(f"TC1 Result: d={d_out}, theta={theta_out}")
        raise TestFailure("Test Case 1 values incorrect")
    
    print("Test Case 1 Passed")

    # --- Test Case 2: Impossible ---
    # Input: 20 30
    # 2 15 20 2 24 18 28 10
    # w=20, l=30, r=2, x1=15, y1=20, x2=2, y2=24, x3=18, y3=28, h=10
    
    # Reset sequence again or just trigger start
    # Assuming DUT can be restarted from IDLE
    
    await send_inputs(20, 30, 2, 15, 20, 2, 24, 18, 28, 10)
    
    timeout = 0
    while not dut.done.value and not dut.impossible.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if not dut.impossible.value:
        raise TestFailure("Test Case 2 failed: Should be impossible")
    
    print("Test Case 2 Passed")
    print("All tests passed")
