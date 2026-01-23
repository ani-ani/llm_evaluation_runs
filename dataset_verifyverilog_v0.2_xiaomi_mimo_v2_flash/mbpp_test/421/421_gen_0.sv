module tuple_concat (
    input clk,
    input rst_n,
    input start,
    input [31:0] str0,
    input [31:0] str1,
    input [31:0] str2,
    input [31:0] str3,
    output reg [127:0] result,
    output reg done
);

    // States
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE_STATE = 2'b10;

    reg [1:0] state;
    reg [1:0] next_state;

    // Delimiter ASCII value for '-'
    localparam [7:0] HYPHEN = 8'h2D;

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = PROCESSING;
                else
                    next_state = IDLE;
            end
            PROCESSING: begin
                next_state = DONE_STATE;
            end
            DONE_STATE: begin
                if (start)
                    next_state = PROCESSING;
                else
                    next_state = DONE_STATE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Output Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 128'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    // result remains as is (or cleared if desired, prompt says clear on reset)
                end
                PROCESSING: begin
                    // Construct the 128-bit result
                    // Byte order: Big-endian typically means MSB is first character
                    // str0[31:24] is byte 3 (MSB of str0), str0[23:16] byte 2, etc.
                    // We want: str0 bytes, hyphen, str1 bytes, hyphen, str2 bytes, hyphen, str3 bytes
                    // Result[127:120] = str0[31:24]
                    // ...
                    // Result[96:89] = str0[0:7]
                    // Result[88:81] = HYPHEN
                    // Result[80:73] = str1[31:24]
                    // ...
                    // Result[48:41] = str2[0:7]
                    // Result[40:33] = HYPHEN
                    // Result[32:25] = str3[31:24]
                    // ...
                    // Result[7:0] = str3[0:7]

                    result[127:120] <= str0[31:24];
                    result[119:112] <= str0[23:16];
                    result[111:104] <= str0[15:8];
                    result[103:96]  <= str0[7:0];
                    
                    result[95:88]   <= HYPHEN;

                    result[87:80]   <= str1[31:24];
                    result[79:72]   <= str1[23:16];
                    result[71:64]   <= str1[15:8];
                    result[63:56]   <= str1[7:0];

                    result[55:48]   <= HYPHEN;

                    result[47:40]   <= str2[31:24];
                    result[39:32]   <= str2[23:16];
                    result[31:24]   <= str2[15:8];
                    result[23:16]   <= str2[7:0];

                    result[15:8]    <= HYPHEN;

                    result[7:0]     <= str3[31:24];
                    // Note: Prompt output format example "ID-is-4-UTS" is 11 chars. 
                    // "ID  " is 4 chars, "is  " is 4, "4   " is 4, "UTS " is 4. 
                    // Total chars = 4+1+4+1+4+1+4 = 19 chars. 
                    // Prompt says: "str0 (bytes 3-0), '-', str1 (bytes 3-0)..."
                    // I will concatenate all 4 bytes of each input, strictly following instructions.
                    // However, I notice the Result register is 128 bits (16 bytes). 
                    // 19 chars won't fit in 16 bytes. 
                    // Let's re-read: "max 16 chars + 3 delimiters = 19 chars, padded to 128 bits".
                    // Wait, if result is 128 bits, it's 16 bytes. 
                    // If we have 4 strings of 4 bytes, that's 16 bytes. 
                    // Plus 3 delimiters = 19 bytes (152 bits). 
                    // There is a contradiction in the description vs output width.
                    // "The final output is a packed 128-bit value."
                    // "Output: 0x49442D69732D342D555453..."
                    // Example output hex: 49 44 2D 69 73 2D 34 20 2D 55 54 53 20 ...
                    // Wait, example input: str0=0x49442020 (ID-space-space-space)
                    // str1=0x69732020 (is-space-space-space)
                    // str2=0x34202020 (4-space-space-space)
                    // str3=0x55545320 (UTS-space)
                    // Example output hex: 0x49442D69732D342D555453...
                    // Bytes: 49 44 2D 69 73 2D 34 2D 55 54 53 (This is 11 bytes so far)
                    // This matches "ID-is-4-UTS" (ID(2) + - + is(2) + - + 4(1) + - + UTS(3) = 11 chars).
                    // It seems the example does NOT include the spaces. 
                    // "Note: The Python function converts numbers to strings; here, we assume inputs are pre-formatted..."
                    // "str0 (bytes 3-0), '-', str1 (bytes 3-0)..."
                    // The instruction "str0 (bytes 3-0)" implies concatenating all 4 bytes of the input.
                    // If the intent is to pack 4 inputs + 3 delimiters into 128 bits, that requires 19 bytes.
                    // Since 128 bits is only 16 bytes, there must be truncation or the prompt implies valid data is packed into 128 bits and rest is ignored, OR the delimiter is part of the byte count in a way I'm misreading.
                    // Let's look at the size constraint again: "max 16 chars + 3 delimiters = 19 chars, padded to 128 bits". 
                    // This is mathematically wrong (128 bits = 16 bytes). 
                    // Maybe the example "ID-is-4-UTS" is representative but strictly it should be 19 bytes? 
                    // Or maybe the inputs are actually 3 bytes plus 1 byte header or something?
                    // Let's strictly follow the code logic requested: "str0 (bytes 3-0), '-', str1 (bytes 3-0), '-', str2 (bytes 3-0), '-', str3 (bytes 3-0)".
                    // This is 4+1+4+1+4+1+4 = 19 bytes. 
                    // I cannot fit 19 bytes into 16 bytes. 
                    // I will assume the result register is intended to hold 128 bits, and I must fit the 19 bytes or truncate.
                    // Given the strict 128-bit output, I will write the first 16 bytes of the stream.
                    // Alternatively, maybe the user meant 128 bits for 4x32bit inputs, and the "padding" is for unused bits.
                    // But "max 16 chars + 3 delimiters" comment suggests 19 bytes.
                    // I will implement the logic that packs the data into the 128-bit register as best as possible, truncating the last bytes.
                    // 128 bits = 16 bytes. 
                    // Bytes 0-3: str0
                    // Bytes 4: '-'
                    // Bytes 5-8: str1
                    // Bytes 9: '-'
                    // Bytes 10-13: str2
                    // Bytes 14: '-'
                    // Bytes 15: str3[31:24] (only 1 byte of str3 fits)
                    // This seems wrong. 
                    // Let's reconsider the "128-bit output". Maybe it's a concatenation of 4x32bit + 0s?
                    // No, "result is a 128-bit vector representing the concatenated string".
                    // "padded to 128 bits" implies the data is shorter, OR fits exactly.
                    // If 19 bytes is the length, it doesn't fit.
                    // However, looking at the example again: "Output: 0x49442D69732D342D555453..."
                    // 49 44 2D 69 73 2D 34 2D 55 54 53
                    // This is only 11 bytes. 
                    // The example input strings were "ID  ", "is  ", "4   ", "UTS ".
                    // The example output used "ID", "is", "4", "UTS" (stripping spaces). 
                    // But the instruction says "each element is a 4-byte (32-bit) value... we will perform the concatenation purely based on byte values".
                    // If I strictly follow the byte concatenation instruction without stripping spaces:
                    // "ID  -is  -4   -UTS "
                    // This is 4+1+4+1+4+1+4 = 19 bytes.
                    // I will assume the prompt has a typo in the width description or the example.
                    // Given the strict interface definition: `output reg [127:0] result`, I must produce 128 bits.
                    // I will implement the concatenation logic that fits into 128 bits. 
                    // Since 19 bytes > 16 bytes, I will prioritize fitting the first parts.
                    // However, usually in these tasks, if 128 bits is given, the data fits.
                    // Is it possible the 'max 16 chars + 3 delimiters' refers to valid ASCII characters, but the input is 32-bit words? 
                    // Yes. The output is 128 bits. 
                    // Let's map the 128 bits exactly:
                    // Bits 127:0.
                    // I'll map the bytes sequentially.
                    // If 19 bytes are generated, the last 3 bytes of str3 will be truncated or result will wrap.
                    // Actually, let's look at the prompt's "Example Input to Output mapping" hex again.
                    // Input hex: 49442020, 69732020, 34202020, 55545320
                    // Output hex: 49442D69732D342D555453...
                    // Breakdown:
                    // 49 44 2D -> "ID-"
                    // 69 73 2D -> "is-"
                    // 34 2D -> "4-" (Wait, input 3 is 34 20 20 20, but output has 34 2D. It skipped the spaces!)
                    // 55 54 53 ... -> "UTS"
                    // It seems the example output ignores the trailing spaces in the 4-byte input. 
                    // But the instruction says "we will perform the concatenation purely based on byte values".
                    // This is confusing.
                    // Let's stick to the explicit algorithm step 3:
                    // "str0 (bytes 3-0), '-', str1 (bytes 3-0), '-', str2 (bytes 3-0), '-', str3 (bytes 3-0)"
                    // This is the clearest instruction. 
                    // 4 bytes * 4 inputs + 3 bytes = 19 bytes.
                    // I will pack what fits into 128 bits. 
                    // However, a safer interpretation for a synthesizable module that fits 128-bit output is that the "padding" mentioned allows it to fit.
                    // Maybe the output format is just the raw bytes, and the trailing bytes in the 128-bit reg are garbage/undefined? 
                    // Usually, we pad with zeros or spaces. 
                    // Let's assume the output is exactly the concatenation, and we slice it to 128 bits.
                    // I'll implement the logic to write all 19 bytes if possible, but since the reg is 128 bits, I will write the first 16 bytes into the register.
                    // Wait, if I write 16 bytes into 128 bits, that's full utilization.
                    // Let's calculate the byte positions in the 128-bit register (Big Endian):
                    // [127:120] -> Byte 0
                    // ...
                    // [7:0] -> Byte 15
                    // 
                    // Sequence to pack: S0[0], S0[1], S0[2], S0[3], '-', S1[0]... (Assuming S0[0] is MSB of input? Or LSB?)
                    // Input is [31:0]. 
                    // Example: 0x49442020. 
                    // MSB: 0x49 ('I'), 0x44 ('D'), 0x20 (' '), 0x20 (' ').
                    // This corresponds to bytes 3, 2, 1, 0 of the 32-bit word.
                    // If we treat the input as a string, we read MSB to LSB.
                    // So the stream is:
                    // S0[31:24], S0[23:16], S0[15:8], S0[7:0], '-', 
                    // S1[31:24]...
                    // 
                    // 128-bit Register layout:
                    // R[127:120] = S0[31:24]
                    // R[119:112] = S0[23:16]
                    // R[111:104] = S0[15:8]
                    // R[103:96] = S0[7:0]
                    // R[95:88] = '-'
                    // R[87:80] = S1[31:24]
                    // R[79:72] = S1[23:16]
                    // R[71:64] = S1[15:8]
                    // R[63:56] = S1[7:0]
                    // R[55:48] = '-'
                    // R[47:40] = S2[31:24]
                    // R[39:32] = S2[23:16]
                    // R[31:24] = S2[15:8]
                    // R[23:16] = S2[7:0]
                    // R[15:8] = '-'
                    // R[7:0] = S3[31:24] (Only fits the first byte of str3)
                    // This results in 16 bytes written.
                    // This matches 128-bit width.
                    // I will implement this truncation. It is the only way to satisfy "128-bit result" and "concatenate all inputs".

                    // Implementation of the 16-byte packing (truncating last 3 bytes of str3)
                    // Note: To strictly follow the "bytes 3-0" order from the prompt:
                    // str0 bytes 3-0 -> [31:24], [23:16], [15:8], [7:0]
                    // This fills 127:96.
                    // Delimiter at 95:88.
                    // str1 bytes 3-0 -> 87:80, 79:72, 71:64, 63:56.
                    // Delimiter at 55:48.
                    // str2 bytes 3-0 -> 47:40, 39:32, 31:24, 23:16.
                    // Delimiter at 15:8.
                    // str3 byte 3 -> 7:0.
                    // Total bytes used: 4 + 1 + 4 + 1 + 4 + 1 + 1 = 16 bytes.
                    // This fits perfectly into 128 bits.
                    // It sacrifices the last 3 bytes of str3. 
                    // I will proceed with this mapping.

                    result[127:120] <= str0[31:24];
                    result[119:112] <= str0[23:16];
                    result[111:104] <= str0[15:8];
                    result[103:96]  <= str0[7:0];
                    
                    result[95:88]   <= HYPHEN;

                    result[87:80]   <= str1[31:24];
                    result[79:72]   <= str1[23:16];
                    result[71:64]   <= str1[15:8];
                    result[63:56]   <= str1[7:0];

                    result[55:48]   <= HYPHEN;

                    result[47:40]   <= str2[31:24];
                    result[39:32]   <= str2[23:16];
                    result[31:24]   <= str2[15:8];
                    result[23:16]   <= str2[7:0];

                    result[15:8]    <= HYPHEN;

                    result[7:0]     <= str3[31:24];
                end
                DONE_STATE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule