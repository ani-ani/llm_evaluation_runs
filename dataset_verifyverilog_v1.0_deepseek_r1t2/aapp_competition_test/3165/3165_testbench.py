import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Helper functions (mandatory)
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

# Packing helper functions
def pack_rook_data(rooks):
    result = 0
    for i, (row, col, power) in enumerate(rooks):
        row_val = row & 0x3
        col_val = col & 0x3
        power_val = power & 0xFF
        entry = (row_val << 10) | (col_val << 8) | power_val
        result |= entry << (i * 12)
    return result

def pack_move_data(moves):
    result = 0
    for i, (sr, sc, dr, dc) in enumerate(moves):
        sr_val = sr & 0x3
        sc_val = sc & 0x3
        dr_val = dr & 0x3
        dc_val = dc & 0x3
        entry = sr_val | (sc_val << 2) | (dr_val << 4) | (dc_val << 6)
        result |= entry << (i * 8)
    return result

# Main test
@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_chess_rook_attacker(dut):
    dut._log.info('Starting test')

    # Detect required signals
    if not has_signal(dut, 'rook_data') or not has_signal(dut, 'move_data') or \
       not has_signal(dut, 'k') or not has_signal(dut, 'p') or \
       not has_signal(dut, 'result0'):
        raise TestFailure('Required signals missing')

    # Test cases: (k, p, rooks, moves, expected_outputs)
    # rooks and moves are 0-based
    test_cases = [
        (2, 2, [(0,0,1), (1,1,1)], [(1,1,1,0), (0,0,0,1)], [4, 0]),
        (2, 2, [(0,0,1), (1,1,2)], [(1,1,1,0), (0,0,0,1)], [4, 2]),
        (3, 3, [(0,0,1), (1,1,2), (1,2,3)], [(1,2,2,2), (2,2,2,0), (0,0,0,1), (2,0,2,1)], [6, 7, 7, 9]),
    ]

    for test_idx, (k, p, rooks, moves, expected) in enumerate(test_cases):
        dut._log.info('Test case ' + str(test_idx+1))

        # Pack inputs
        rook_data = pack_rook_data(rooks)
        move_data = pack_move_data(moves)

        # Set inputs
        dut.rook_data.value = rook_data
        dut.move_data.value = move_data
        dut.k.value = k
        dut.p.value = p

        # Wait for propagation
        await Timer(100, units='ns')

        # Read results
        results = []
        for i in range(4):
            sig_name = 'result' + str(i)
            if has_signal(dut, sig_name):
                val = getattr(dut, sig_name).value
                if is_value_defined(val):
                    results.append(int(val))
                else:
                    results.append(0)
            else:
                results.append(0)

        # Verify results
        for i in range(p):
            actual = results[i]
            expected_val = expected[i]
            if actual != expected_val:
                raise TestFailure('Test ' + str(test_idx+1) + ', move ' + str(i) + ': expected ' + str(expected_val) + ', got ' + str(actual))
            else:
                dut._log.info('  Move ' + str(i) + ': OK')

        dut._log.info('Test ' + str(test_idx+1) + ' passed')

    dut._log.info('All tests passed')