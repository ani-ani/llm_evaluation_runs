import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# Generate all 16-bit Sheldon numbers for test reference
def generate_sheldon_numbers_16bit():
    S = set()
    # Pattern1: (AB)^k A
    for N in range(1, 17):  # 1 to 16 ones
        for M in range(1, 17):  # 1 to 16 zeros
            k = 0
            while True:
                total_bits = (N + M) * k + N
                if total_bits > 16:
                    break
                s = ''
                for i in range(2 * k + 1):
                    if i % 2 == 0:
                        s += '1' * N
                    else:
                        s += '0' * M
                num = int(s, 2)
                if 0 < num <= 65535:  # Only positive numbers
                    S.add(num)
                k += 1
    
    # Pattern2: (AB)^k
    for N in range(1, 17):
        for M in range(1, 17):
            k = 1
            while True:
                total_bits = (N + M) * k
                if total_bits > 16:
                    break
                s = ''
                for i in range(2 * k):
                    if i % 2 == 0:
                        s += '1' * N
                    else:
                        s += '0' * M
                num = int(s, 2)
                if 0 < num <= 65535:
                    S.add(num)
                k += 1
    return sorted(S)

# Precompute expected Sheldon numbers
SHELDON_NUMS = generate_sheldon_numbers_16bit()
print(f"Generated {len(SHELDON_NUMS)} Sheldon numbers up to 65535")

@cocotb.test(timeout_time=10, timeout_unit='ms')
async def test_sheldon_counter(dut):
    """Test the Sheldon number counter module"""
    
    # Configuration
    CLK_PERIOD = 10  # ns
    MAX_CYCLES = 500  # Should complete within 500 cycles
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.x.value = 0
    dut.y.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Wait a bit for reset to propagate
    await Timer(100, units='ns')
    
    # Test cases: (x, y, expected_count)
    test_cases = [
        (1, 10, len([n for n in SHELDON_NUMS if 1 <= n <= 10])),
        (70, 75, len([n for n in SHELDON_NUMS if 70 <= n <= 75])),
        (0, 100, len([n for n in SHELDON_NUMS if 0 <= n <= 100])),
        (1000, 2000, len([n for n in SHELDON_NUMS if 1000 <= n <= 2000])),
        (50000, 60000, len([n for n in SHELDON_NUMS if 50000 <= n <= 60000])),
        (0, 65535, len(SHELDON_NUMS)),  # All Sheldon numbers
    ]
    
    for i, (x, y, expected) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: X={x}, Y={y}, Expected={expected}")
        
        # Set inputs
        dut.x.value = x
        dut.y.value = y
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal
        cycles = 0
        done = False
        while cycles < MAX_CYCLES:
            await RisingEdge(dut.clk)
            cycles += 1
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            raise TestFailure(f"Test {i+1}: Timeout after {cycles} cycles")
        
        # Read result
        if not is_value_defined(dut.count.value):
            raise TestFailure(f"Test {i+1}: Count is undefined")
        
        result = int(dut.count.value)
        
        if result != expected:
            raise TestFailure(
                f"Test {i+1} FAILED: X={x}, Y={y}, "
                f"Expected={expected}, Got={result}"
            )
        
        dut._log.info(f"  PASS: count = {result}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info("All tests passed!")