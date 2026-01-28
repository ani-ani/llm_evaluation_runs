import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_fruit_game(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.x_i.value = 0
    dut.y_i.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases
    test_cases = [
        (1, 4, "3B"),
        (2, 2, "Impossible"),
        (3, 2, "1A1B"),
        (2, 1, "1A"),
        (5, 3, "1A1B1A"),
        (5, 2, "2A1B"),
        (8, 5, "1A1B1A1B"),
        (1, 3, "2B"),
    ]

    for x, y, expected in test_cases:
        dut.x_i.value = x
        dut.y_i.value = y
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        segments = []
        done_seen = False
        impossible = False
        
        # Wait for outputs
        for _ in range(2000): # Safety timeout
            await RisingEdge(dut.clk)
            if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
                char = chr(int(dut.result_char.value))
                count = int(dut.result_count.value)
                segments.append(f"{count}{char}")
            
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done_seen = True
                if is_value_defined(dut.impossible.value) and int(dut.impossible.value) == 1:
                    impossible = True
                break
        
        if not done_seen:
            raise TestFailure(f"Timeout for input {x} {y}")
        
        result_str = "".join(segments)
        if impossible:
            result_str = "Impossible"
            
        if result_str != expected:
            raise TestFailure(f"Input ({x},{y}): Expected '{expected}', got '{result_str}'")
        
        dut._log.info(f"Passed: ({x},{y}) -> {result_str}")

    # Edge case: large numbers
    dut.x_i.value = 1000000000000000000
    dut.y_i.value = 999999999999999999
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    segments = []
    for _ in range(5000): # Large test might take more cycles
        await RisingEdge(dut.clk)
        if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
            char = chr(int(dut.result_char.value))
            count = int(dut.result_count.value)
            segments.append(f"{count}{char}")
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
    
    result_str = "".join(segments)
    expected_large = "1A999999999999999998B"
    if result_str != expected_large:
         raise TestFailure(f"Large input: Expected '{expected_large}', got '{result_str}'")
    dut._log.info(f"Passed: Large input -> {result_str}")

    # Impossible case: 1000000000000000000 1000000000000000000
    dut.x_i.value = 1000000000000000000
    dut.y_i.value = 1000000000000000000
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    for _ in range(1000):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
    
    if not (is_value_defined(dut.impossible.value) and int(dut.impossible.value) == 1):
        raise TestFailure(f"Impossible case failed to set flag")
    dut._log.info(f"Passed: Impossible case detected")
