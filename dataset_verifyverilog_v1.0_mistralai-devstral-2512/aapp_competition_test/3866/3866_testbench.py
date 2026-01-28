import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_lucky_permutation_triple(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        clock = Clock(dut.clk, 10, units='ns')
        cocotb.start_soon(clock.start())
    else:
        raise TestFailure("Module requires 'clk' signal")

    await reset_dut(dut)

    # Test cases: (n, should_be_valid)
    test_cases = [
        (5, True),   # Odd
        (2, False),  # Even
        (9, True),   # Odd
        (1, True),   # Odd
        (6, False),  # Even
        (31, True),  # Odd (max limit)
    ]

    for n, should_be_valid in test_cases:
        cocotb.log.info(f"Testing n={n}, expected valid={should_be_valid}")
        
        # Check signals exist
        if not has_signal(dut, 'n_in') or not has_signal(dut, 'start'):
             raise TestFailure("Missing input signals n_in or start")
        if not has_signal(dut, 'valid') or not has_signal(dut, 'done'):
             raise TestFailure("Missing output signals valid or done")

        # Drive inputs
        dut.n_in.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Internal memory to verify correctness (Address -> Value)
        mem_a = {}
        mem_b = {}
        mem_c = {}

        # Monitor writes
        max_cycles = 50  # n is small (max 32), so 50 cycles is plenty
        cycles = 0
        done_seen = False

        while cycles < max_cycles:
            await RisingEdge(dut.clk)
            cycles += 1

            # Check valid signal (should be stable once start is low)
            if is_value_defined(dut.valid.value):
                valid_val = int(dut.valid.value)
                if valid_val != (1 if should_be_valid else 0):
                    raise TestFailure(f"Cycle {cycles}: Expected valid={1 if should_be_valid else 0}, got {valid_val}")

            # Capture writes
            if has_signal(dut, 'wr_en') and is_value_defined(dut.wr_en.value) and int(dut.wr_en.value) == 1:
                if not (has_signal(dut, 'addr_a') and has_signal(dut, 'data_a')):
                     raise TestFailure("Missing write ports")
                
                addr_a = int(dut.addr_a.value)
                data_a = int(dut.data_a.value)
                addr_b = int(dut.addr_b.value)
                data_b = int(dut.data_b.value)
                addr_c = int(dut.addr_c.value)
                data_c = int(dut.data_c.value)
                
                mem_a[addr_a] = data_a
                mem_b[addr_b] = data_b
                mem_c[addr_c] = data_c
                
                # Verify write correctness immediately
                # Expected: a[i]=i, b[i]=i, c[i]=(2*i)%n
                if addr_a != data_a:
                    raise TestFailure(f"Write mismatch: a[{addr_a}] = {data_a} (expected {addr_a})")
                if addr_b != data_b:
                    raise TestFailure(f"Write mismatch: b[{addr_b}] = {data_b} (expected {addr_b})")
                
                expected_c = (addr_c * 2) % n
                if data_c != expected_c:
                    raise TestFailure(f"Write mismatch: c[{addr_c}] = {data_c} (expected {expected_c})")

            # Check done
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done_seen = True
                break

        if not done_seen:
            raise TestFailure(f"Done signal not asserted within {max_cycles} cycles")

        # Verify completeness
        if should_be_valid:
            if len(mem_a) != n:
                raise TestFailure(f"Incomplete permutation a: expected {n} writes, got {len(mem_a)}")
            if len(mem_b) != n:
                raise TestFailure(f"Incomplete permutation b: expected {n} writes, got {len(mem_b)}")
            if len(mem_c) != n:
                raise TestFailure(f"Incomplete permutation c: expected {n} writes, got {len(mem_c)}")
            
            # Verify c is a permutation (all values 0..n-1 present)
            c_values = list(mem_c.values())
            c_values.sort()
            if c_values != list(range(n)):
                 raise TestFailure(f"c is not a valid permutation. Values: {c_values}")
        else:
            # If invalid, ensure no writes happened
            if len(mem_a) > 0:
                 raise TestFailure("Writes occurred for even n (should be invalid)")

        await RisingEdge(dut.clk)  # Buffer cycle
