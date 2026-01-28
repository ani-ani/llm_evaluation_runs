import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
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

@cocotb.test(timeout_time=500, timeout_unit='ms')
async def test_swap_gen(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        clk = Clock(dut.clk, 10, units='ns')
        cocotb.start_soon(clk.start())
        await reset_dut(dut)
    else:
        await Timer(10, units='ns')

    test_cases = [
        (1, True, "n=1 should be YES"),
        (2, False, "n=2 should be NO"),
        (3, False, "n=3 should be NO"),
        (4, True, "n=4 should be YES"),
        (5, True, "n=5 should be YES"),
        (6, False, "n=6 should be NO"),
        (7, False, "n=7 should be NO"),
        (8, True, "n=8 should be YES")
    ]

    for n, exp_possible, desc in test_cases:
        cocotb.log.info(f"Testing {desc}")
        
        # Set inputs
        dut.n.value = n
        
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, max_cycles=100)
        else:
            # Combinational or just wait
            await Timer(100, units='ns')
            
        # Check possible
        if has_signal(dut, 'possible'):
            possible = int(dut.possible.value)
            expected = 1 if exp_possible else 0
            if possible != expected:
                raise TestFailure(f"{desc}: Expected possible={expected}, got {possible}")
        
        # If possible, verify swaps are generated
        if exp_possible and has_signal(dut, 'valid'):
            swaps = []
            max_cycles = 100
            cycles = 0
            # Monitor valid signals
            # We check if valid is asserted for some cycles
            while cycles < max_cycles:
                await RisingEdge(dut.clk)
                if int(dut.valid.value) == 1:
                    a = int(dut.pair_a.value)
                    b = int(dut.pair_b.value)
                    swaps.append((a, b))
                    cocotb.log.info(f"Swap {len(swaps)}: ({a}, {b})")
                    if a >= b:
                        raise TestFailure(f"Invalid swap: a={a}, b={b}, must be a < b")
                if int(dut.done.value) == 1:
                    break
                cycles += 1
            
            total_pairs = n * (n - 1) // 2
            if len(swaps) != total_pairs:
                raise TestFailure(f"{desc}: Expected {total_pairs} swaps, got {len(swaps)}")
            
            # Verify all pairs are present exactly once
            found_pairs = set(swaps)
            if len(found_pairs) != len(swaps):
                raise TestFailure(f"Duplicate swaps detected")
                
            expected_pairs = set()
            for i in range(n):
                for j in range(i + 1, n):
                    expected_pairs.add((i, j))
            
            if found_pairs != expected_pairs:
                missing = expected_pairs - found_pairs
                extra = found_pairs - expected_pairs
                raise TestFailure(f"Mismatched pairs. Missing: {missing}, Extra: {extra}")

        cocotb.log.info(f"Test passed for n={n}")
