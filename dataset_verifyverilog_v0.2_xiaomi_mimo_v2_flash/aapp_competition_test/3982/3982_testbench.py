import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
import random

MOD = 10**9 + 7
BAD = {"0011", "0101", "1110", "1111"}

def is_valid_code(s):
    if len(s) == 0: return False
    if len(s) > 4: return False
    if len(s) == 4 and s in BAD: return False
    return True

def count_sequences(s):
    if not s: return 0
    dp = [0] * len(s)
    total = 0
    for i in range(len(s)):
        current_sum = 0
        # Check all substrings ending at i
        for length in range(1, 5):
            if i - length + 1 >= 0:
                sub = s[i - length + 1 : i + 1]
                if is_valid_code(sub):
                    if i - length >= 0:
                        current_sum = (current_sum + dp[i - length]) % MOD
                    else:
                        current_sum = (current_sum + 1) % MOD
        dp[i] = current_sum
        total = (total + dp[i]) % MOD
    return total

@cocotb.test()
async def test_morse_decoder(dut):
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.bit_in.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test inputs (shortened for hardware limits)
    # Using first 12 bits of the provided test case
    input_bits = [1, 1, 0, 0, 0, 1, 1, 0, 1, 0, 0, 1][:12] 
    s_history = ""
    
    dut._log.info(f"Starting test with inputs: {input_bits}")

    for i, bit in enumerate(input_bits):
        s_history += str(bit)
        expected = count_sequences(s_history)
        
        # Start calculation
        dut.bit_in.value = bit
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (latency ~50 cycles)
        cycles = 0
        while not dut.done.value and cycles < 60:
            await RisingEdge(dut.clk)
            cycles += 1
        
        # Check result
        actual = int(dut.result.value)
        dut._log.info(f"Step {i+1}: S='{s_history}', Expected={expected}, Got={actual}")
        assert actual == expected, f"Mismatch at step {i+1}: expected {expected}, got {actual}"
        
        await RisingEdge(dut.clk)

    dut._log.info(f"All tests passed.")
