import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

def to_signed(val, bits=3):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits=3):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def generate_polynomials(n):
    if n == 0:
        return [1], None
    polys = {}
    polys[0] = [1]
    polys[1] = [0, 1]
    if n == 1:
        return polys[1], polys[0]
    for i in range(2, n + 1):
        cand1 = [0] + polys[i - 1]
        for j in range(len(polys[i - 2])):
            cand1[j] += polys[i - 2][j]
        if all(abs(x) <= 1 for x in cand1):
            polys[i] = cand1
        else:
            cand2 = [0] + polys[i - 1]
            for j in range(len(polys[i - 2])):
                cand2[j] -= polys[i - 2][j]
            if all(abs(x) <= 1 for x in cand2):
                polys[i] = cand2
            else:
                return None, None
    return polys[n], polys[n - 1]

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_polynomial_generator(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test n from 1 to 8
    for n_val in range(1, 9):
        dut._log.info(f"Testing n={n_val}")
        # Generate expected polynomials
        exp1, exp2 = generate_polynomials(n_val)
        if exp1 is None:
            dut._log.error(f"Generation failed for n={n_val}")
            raise TestFailure("Generation failed")
        
        # Set n and start
        dut.n.value = n_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (with timeout)
        cycles = 0
        while not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > 1000:
                raise TestFailure(f"Timeout for n={n_val}")
        
        # Read degrees
        deg1 = to_signed(int(dut.out_degree1.value), 4)
        deg2 = to_signed(int(dut.out_degree2.value), 4)
        
        if deg1 != n_val or deg2 != n_val - 1:
            raise TestFailure(f"Degrees mismatch for n={n_val}: expected ({n_val}, {n_val-1}), got ({deg1}, {deg2})")
        
        # Read coefficients
        coeffs1 = []
        for i in range(deg1 + 1):
            if has_signal(dut, f'out_coeffs1[{i}]'):
                val = getattr(dut, f'out_coeffs1[{i}]').value
            else:
                val = dut.out_coeffs1[i].value
            if is_value_defined(val):
                coeffs1.append(to_signed(int(val), 3))
            else:
                coeffs1.append(None)
        
        coeffs2 = []
        for i in range(deg2 + 1):
            if has_signal(dut, f'out_coeffs2[{i}]'):
                val = getattr(dut, f'out_coeffs2[{i}]').value
            else:
                val = dut.out_coeffs2[i].value
            if is_value_defined(val):
                coeffs2.append(to_signed(int(val), 3))
            else:
                coeffs2.append(None)
        
        # Compare with expected
        if len(coeffs1) != len(exp1):
            raise TestFailure(f"Polynomial1 length mismatch for n={n_val}: expected {len(exp1)}, got {len(coeffs1)}")
        for i, (c, e) in enumerate(zip(coeffs1, exp1)):
            if c != e:
                raise TestFailure(f"Polynomial1 coeff {i} mismatch for n={n_val}: expected {e}, got {c}")
        
        if len(coeffs2) != len(exp2):
            raise TestFailure(f"Polynomial2 length mismatch for n={n_val}: expected {len(exp2)}, got {len(coeffs2)}")
        for i, (c, e) in enumerate(zip(coeffs2, exp2)):
            if c != e:
                raise TestFailure(f"Polynomial2 coeff {i} mismatch for n={n_val}: expected {e}, got {c}")
        
        dut._log.info(f"Test n={n_val} passed")
        await RisingEdge(dut.clk)
