import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

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

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def trailing_zeros(x):
    cnt = 0
    while x % 2 == 0:
        cnt += 1
        x //= 2
    return cnt

def compute_expected_mask(numbers, n):
    tz = [trailing_zeros(x) for x in numbers]
    from collections import Counter
    cnt = Counter(tz)
    most_common = cnt.most_common(1)[0][0]
    mask = 0
    for i in range(n):
        if tz[i] != most_common:
            mask |= (1 << i)
    return mask

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_bipartite_remover(dut):
    "Test the bipartite_remover module."
    N = 4
    W = 16

    test_cases = [
        [1, 2, 3, 4],
        [2, 6, 10, 14],
        [1, 3, 5, 7],
        [2, 4, 6, 8],
    ]

    for idx, numbers in enumerate(test_cases):
        dut._log.info(f"Test case {idx+1}: {numbers}")
        
        for i in range(N):
            val = clamp_to_width(numbers[i], W)
            if has_signal(dut, f'arr_{i}'):
                getattr(dut, f'arr_{i}').value = val
            else:
                dut.arr[i].value = val
        
        await Timer(10, units='ns')
        
        mask_val = 0
        if has_signal(dut, 'remove_mask'):
            mask_val = int(dut.remove_mask.value)
        else:
            for i in range(N):
                port_name = f'remove_mask_{i}'
                if has_signal(dut, port_name):
                    if int(getattr(dut, port_name).value):
                        mask_val |= (1 << i)
                else:
                    raise TestFailure("Cannot read remove_mask")
        
        expected = compute_expected_mask(numbers, N)
        if mask_val != expected:
            raise TestFailure(f"Test {idx+1}: Expected mask {expected:04b}, got {mask_val:04b}")
        
        dut._log.info(f"  PASS: mask = {mask_val:04b}")
    
    dut._log.info("All tests passed!")