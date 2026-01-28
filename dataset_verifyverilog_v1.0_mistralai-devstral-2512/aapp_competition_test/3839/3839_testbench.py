import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

CLK_NS = 10
MAX_CYCLES = 1500

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def wait_for_done(dut, max_cycles=1500):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

def generate_expected_coords(n):
    coords = []
    groups = n // 3
    remainder = n % 3
    for i in range(groups):
        coords.append((2*i, 0))
        coords.append((2*i + 1, 0))
        coords.append((2*i + 1, 3))
    for i in range(remainder):
        coords.append((2*groups + i, 0))
    return coords

@cocotb.test(timeout_time=15000, timeout_unit="ms")
async def test_knight_generation(dut):
    # Setup clock
    clock = Clock(dut.clk, CLK_NS, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases
    test_values = [1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 31, 34, 37, 40, 100, 500, 999, 1000]
    passed = 0
    failed = 0
    
    for n in test_values:
        cocotb.log.info(f"Testing n={n}")
        
        # Expected coordinates
        expected = generate_expected_coords(n)
        
        # Start generation
        dut.n.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Collect outputs
        collected = []
        got_done = False
        
        for cycle in range(n + 100):  # Allow extra cycles for safety
            await RisingEdge(dut.clk)
            
            # Check valid
            if has_signal(dut, 'valid') and is_value_defined(dut.valid.value):
                valid = int(dut.valid.value)
                if valid == 1 and cycle < n:
                    # Check coordinates are defined
                    if not is_value_defined(dut.x.value):
                        raise TestFailure(f"x undefined at cycle {cycle}")
                    if not is_value_defined(dut.y.value):
                        raise TestFailure(f"y undefined at cycle {cycle}")
                    x = int(dut.x.value)
                    y = int(dut.y.value)
                    collected.append((x, y))
            
            # Check done
            if has_signal(dut, 'done') and is_value_defined(dut.done.value):
                if int(dut.done.value) == 1:
                    got_done = True
                    break
        
        if not got_done:
            cocotb.log.error(f"FAIL: n={n}, done signal not received")
            failed += 1
            continue
        
        if len(collected) != n:
            cocotb.log.error(f"FAIL: n={n}, expected {n} coordinates, got {len(collected)}")
            failed += 1
            continue
        
        # Verify coordinates match expected pattern
        all_match = True
        for i, (got_x, got_y) in enumerate(collected):
            exp_x, exp_y = expected[i]
            if got_x != exp_x or got_y != exp_y:
                cocotb.log.error(f"FAIL: n={n}, coord {i}: expected ({exp_x},{exp_y}), got ({got_x},{got_y})")
                all_match = False
                break
        
        if all_match:
            passed += 1
            cocotb.log.info(f"PASS: n={n}")
        else:
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All {passed} tests passed")
