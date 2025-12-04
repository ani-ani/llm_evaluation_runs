import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_str_to_tuple(dut):
    test_inputs = [
        ("python 3.0", 10, ("py thon 3.0".replace(" ", "").encode() + b'\\0'*7).hex(), 9),
        ("item1", 5, "item1".encode().hex().ljust(32, '0'), 5),
        ("15.10", 5, "15.10".encode().hex().ljust(32, '0'), 5),
        ("", 0, "0"*32, 0),
        ("   ", 3, "0"*32, 0)
    ]

    passed = 0
    for instr, inlen, expected_hex, expected_len in test_inputs:
        # Pad input to 16 bytes and pack in 128-bit vector
        input_bytes = instr.encode().ljust(16, b'\\0')[:16]
        packed_in = int.from_bytes(input_bytes, byteorder='big')
        
        dut.data_in.value = packed_in
        dut.length.value = inlen
        await Timer(1, units='ns')
        
        # Parse output
        out_bytes = bytes.fromhex(dut.tuple_data.value.binstr.replace('\\s','').zfill(32))
        actual_str = ''.join(chr(b) for b in out_bytes[:int(dut.tuple_length.value) if dut.tuple_length.value < 16 else 16])
        expected_str = bytes.fromhex(expected_hex).decode().rstrip('\\0')
        
        error_msg = f"Input: {instr} ({inlen})
Got: {actual_str} (len={hex(dut.tuple_length.value)})
Exp: {expected_str} (len={expected_len})"

        if dut.tuple_length.value == expected_len and dut.tuple_data.value == int(expected_hex,16):
            passed += 1
            dut._log.info(f"PASS: '{instr}' -> '{expected_str}'")
        else:
            dut._log.error(error_msg)

    # Summary
    dut._log.info(f"TEST SUMMARY: {passed}/{len(test_inputs)} tests passed")