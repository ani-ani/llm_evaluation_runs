import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ADDR_WIDTH = 4  # 4-bit address for 16 entries
LEN_WIDTH = 4
CLK_NS = 10
MAX_CYCLES = 1000

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'input_valid'):
        dut.input_valid.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def send_subnet(dut, ip, length, is_black, last=False):
    if has_signal(dut, 'input_ip'):
        dut.input_ip.value = clamp_to_width(ip, DATA_WIDTH)
    if has_signal(dut, 'input_len'):
        dut.input_len.value = clamp_to_width(length, LEN_WIDTH)
    if has_signal(dut, 'input_is_black'):
        dut.input_is_black.value = is_black
    if has_signal(dut, 'input_last'):
        dut.input_last.value = last
    if has_signal(dut, 'input_valid'):
        dut.input_valid.value = 1
    await RisingEdge(dut.clk)
    if has_signal(dut, 'input_valid'):
        dut.input_valid.value = 0

async def collect_outputs(dut):
    results = []
    max_iters = 100
    for _ in range(max_iters):
        if has_signal(dut, 'output_valid'):
            if int(dut.output_valid.value) == 1:
                ip = safe_int(dut.output_ip.value)
                length = safe_int(dut.output_len.value)
                results.append((ip, length))
        if has_signal(dut, 'done') and int(dut.done.value) == 1:
            break
        await RisingEdge(dut.clk)
    return results

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_ipv4_blacklist_optimizer(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)

    # Test cases: simplified IPs (8-bit), prefix length (0-15)
    # Each case: (list of (ip, length, is_black), expected outputs or -1 for error)
    # Format: (ip, length, is_black) where is_black is True for '-', False for '+'
    test_cases = [
        # Case 1: Simple black subnet, no white
        ([(10, 8, True)], [(10, 8)], None),
        # Case 2: Black and white conflict (overlapping)
        ([(10, 8, True), (10, 8, False)], None, True),
        # Case 3: No conflict, two black subnets
        ([(10, 8, True), (20, 8, True)], [(10, 8), (20, 8)], None),
        # Case 4: Black subnet with white inside (conflict)
        ([(0, 0, True), (5, 8, False)], None, True),
        # Case 5: Optimal merge example (simplified)
        ([(0, 7, True), (128, 7, True)], [(0, 6)], None),  # Should merge to /6 if possible
    ]

    passed = 0
    failed = 0

    for i, (inputs, expected_outputs, expect_error) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {len(inputs)} subnets")
        try:
            if is_seq:
                # Send start pulse
                if has_signal(dut, 'start'):
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                else:
                    await RisingEdge(dut.clk)
            
            # Send all subnets
            for j, (ip, length, is_black) in enumerate(inputs):
                last = (j == len(inputs) - 1)
                await send_subnet(dut, ip, length, 1 if is_black else 0, last)
            
            # Collect results
            if is_seq:
                results = await collect_outputs(dut)
                if expect_error:
                    if not has_signal(dut, 'error') or int(dut.error.value) == 0:
                        raise TestFailure(f"Expected error but none occurred")
                else:
                    if has_signal(dut, 'error') and int(dut.error.value) == 1:
                        raise TestFailure(f"Unexpected error signaled")
                    # Check outputs
                    if expected_outputs is not None:
                        if len(results) != len(expected_outputs):
                            raise TestFailure(f"Expected {len(expected_outputs)} outputs, got {len(results)}")
                        # Check each output (order may vary, but for simplicity assume order)
                        for (res_ip, res_len), (exp_ip, exp_len) in zip(results, expected_outputs):
                            if res_ip != exp_ip or res_len != exp_len:
                                raise TestFailure(f"Output mismatch: got ({res_ip},{res_len}), expected ({exp_ip},{exp_len})")
            else:
                await Timer(100, units='ns')
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed")
