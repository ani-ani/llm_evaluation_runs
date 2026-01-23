module dict_filter (
    input clk,
    input rst_n,
    input start,
    input [7:0] threshold,
    input [3:0] num_entries,
    input [3:0] key_0, key_1, key_2, key_3,
    input [7:0] val_0, val_1, val_2, val_3,
    output reg [59:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam COMPARE = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    reg [2:0] counter, next_counter; // Counter for entries (0 to 4)
    reg [2:0] valid_count, next_valid_count; // Count of valid entries (0 to 4)
    
    // Temporary storage for valid entries
    reg [3:0] temp_keys [0:3];
    reg [7:0] temp_vals [0:3];
    
    // Next temporary storage (for sequential update)
    reg [3:0] next_temp_keys [0:3];
    reg [7:0] next_temp_vals [0:3];
    
    reg [59:0] next_result;
    reg next_done;
    
    // Current entry data selection
    reg [3:0] current_key;
    reg [7:0] current_val;
    
    integer i;

    // Combinational logic for data selection
    always @(*) begin
        case (counter)
            3'd0: begin current_key = key_0; current_val = val_0; end
            3'd1: begin current_key = key_1; current_val = val_1; end
            3'd2: begin current_key = key_2; current_val = val_2; end
            3'd3: begin current_key = key_3; current_val = val_3; end
            default: begin current_key = 4'b0; current_val = 8'b0; end
        endcase
    end

    // Next state and output logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_counter = counter;
        next_valid_count = valid_count;
        next_result = result;
        next_done = done;
        
        // Default temp storage updates (keep old values)
        for (i = 0; i < 4; i = i + 1) begin
            next_temp_keys[i] = temp_keys[i];
            next_temp_vals[i] = temp_vals[i];
        end
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPARE;
                    next_counter = 3'd0;
                    next_valid_count = 3'd0;
                    next_done = 1'b0;
                    // Clear temp storage
                    for (i = 0; i < 4; i = i + 1) begin
                        next_temp_keys[i] = 4'b0;
                        next_temp_vals[i] = 8'b0;
                    end
                end
            end
            
            COMPARE: begin
                // Check if current entry is valid
                if (counter < num_entries && current_val >= threshold) begin
                    // Store valid entry
                    next_temp_keys[valid_count] = current_key;
                    next_temp_vals[valid_count] = current_val;
                    next_valid_count = valid_count + 1'b1;
                end
                
                // Move to next entry
                if (counter < 3'd4) begin
                    next_counter = counter + 1'b1;
                end
                
                // Check if we've processed all entries (4 max)
                if (counter >= 3'd3) begin
                    next_state = DONE;
                    // Pack the results
                    next_result[59:56] = next_valid_count; // Use updated count
                    
                    // Pack entries 0 to 3
                    // Entry 0
                    next_result[55:52] = next_temp_keys[0];
                    next_result[51:48] = next_temp_keys[0]; // Note: spec shows double bits in description, using same
                    next_result[47:40] = next_temp_vals[0];
                    
                    // Entry 1
                    next_result[39:36] = next_temp_keys[1];
                    next_result[35:32] = next_temp_keys[1];
                    next_result[31:24] = next_temp_vals[1];
                    
                    // Entry 2
                    next_result[23:20] = next_temp_keys[2];
                    next_result[19:16] = next_temp_keys[2];
                    next_result[15:8] = next_temp_vals[2];
                    
                    // Entry 3
                    next_result[7:4] = next_temp_keys[3];
                    next_result[3:0] = next_temp_vals[3]; // Note: spec uses 3:0 for both key and val parts in description, correcting to val
                    
                    // Correction on packing based on spec description:
                    // Bits [7:4], [3:0]: Key for entry 3
                    // The description seems to have overlap. Let's follow the explicit bit ranges:
                    // {count, key3, val3, key2, val2, key1, val1, key0, val0}
                    // Key is 4 bits, val is 8 bits
                    // Entry 3: bits [7:4] key, [3:0] should be part of val, but val needs 8 bits
                    // Re-interpreting 59-bit packed format from description:
                    // 4 + (4+8) + (4+8) + (4+8) + (4+8) = 4 + 12*4 = 52 bits. 
                    // The description says 59 bits. 
                    // Let's use: count(4) + key3(4) + val3(8) + key2(4) + val2(8) + key1(4) + val1(8) + key0(4) + val0(8)
                    // Total: 4 + 12 + 12 + 12 + 12 = 52 bits. 
                    // The description bit ranges are slightly confusing, let's implement the packed format as:
                    // {count[3:0], key3[3:0], val3[7:0], key2[3:0], val2[7:0], key1[3:0], val1[7:0], key0[3:0], val0[7:0]}
                    // This is 52 bits. I will pad to 59 bits for future proofing or just use 52.
                    // Wait, the spec says "Bits [7:4], [3:0]: Key for entry 3" - this implies 8 bits for key? No, 4+4=8?
                    // And "Bits [7:0]: Value for entry 3".
                    // This overlap is physically impossible. 
                    // Most likely interpretation of "Bits [A:B], [C:D]: Key" is a typo for "Bits [A:B]: Key".
                    // Or it means {Key, Key}? No.
                    // Let's assume the format is strictly: Count + (Key + Val) * 4.
                    // That is 4 + 12*4 = 52 bits.
                    // However, the prompt says 59 bits. 
                    // Maybe Entry 0 has extra bits? 
                    // Let's implement the most logical packed format:
                    // result = {count, key3, val3, key2, val2, key1, val1, key0, val0}
                    // I will use the bits defined in the description's comments.
                    
                    // Re-reading: "Bits [55:52], [51:48]: Key for entry 0"
                    // This explicitly asks for two fields of 4 bits for Key 0. 
                    // And "Bits [7:0]: Value for entry 3".
                    // If Key0 takes 8 bits total, and Val0 takes 8 bits, Entry 0 is 16 bits.
                    // Entry 1: 16 bits, etc. Count is 4 bits.
                    // 4 + 16*4 = 68 bits. 
                    // But prompt says "Maximum 4 valid outputs (fits in 60-bit output bus)".
                    // 60 bits is the limit. 
                    // Maybe "Bits [55:52], [51:48]: Key for entry 0" means the 4-bit key is replicated or reserved?
                    // Let's assume a standard packing: Count (4) + Key0 (4) + Val0 (8) + Key1 (4) + Val1 (8) + Key2 (4) + Val2 (8) + Key3 (4) + Val3 (8).
                    // Total = 52 bits.
                    // I will implement this efficient packing and pad the upper bits to 59.
                    
                    next_result[59:52] = 8'b0; // Padding to 59 bits
                    next_result[51:48] = next_valid_count; // 4-bit count in the upper nibble of the padding if 8 bits were used, but spec says [59:56].
                    
                    // Correcting the packing logic to match the comment in the interface:
                    // result = {count[3:0], key3[3:0], val3[7:0], key2[3:0], val2[7:0], key1[3:0], val1[7:0], key0[3:0], val0[7:0]}
                    // Wait, the order is key3, val3 ... key0, val0. Usually FIFO order is key0, val0 ...
                    // Let's assume the comments inside the code block are the source of truth for bit ranges.
                    // Bits [59:56]: count
                    // Bits [55:52], [51:48]: Key 0 -> This is 8 bits for key 0? Or is it Key0 and Key1?
                    // "Bits [55:52], [51:48]: Key for entry 0"
                    // "Bits [47:40]: Value for entry 0"
                    // "Bits [39:36], [35:32]: Key for entry 1"
                    // "Bits [31:24]: Value for entry 1"
                    // ...
                    // "Bits [7:4], [3:0]: Key for entry 3" -> This is 8 bits for Key 3.
                    // "Bits [7:0]: Value for entry 3" -> This is 8 bits for Val 3.
                    // This is definitely a conflict in the specification text provided. 
                    // "Bits [7:4], [3:0]: Key for entry 3" and "Bits [7:0]: Value for entry 3" cannot both be true.
                    // I will prioritize the "Packed: {count, key3, val3, key2, val2, key1, val1, key0, val0}" description 
                    // and the bit ranges that make sense (4 bit key, 8 bit val).
                    // I will ignore the contradictory double-key assignments (e.g. [55:52] and [51:48] for Key0).
                    // Interpretation:
                    // Count: 4 bits [59:56]
                    // Entry 0: Key [55:52], Val [51:44] (8 bits? But spec says [47:40])
                    // Spec says: 
                    // Entry 0: Key [55:52], [51:48] (8 bits), Val [47:40] (8 bits)
                    // Entry 1: Key [39:36], [35:32] (8 bits), Val [31:24] (8 bits)
                    // Entry 2: Key [23:20], [19:16] (8 bits), Val [15:8] (8 bits)
                    // Entry 3: Key [7:4], [3:0] (8 bits), Val [7:0] (8 bits)
                    // Wait, "Bits [7:4], [3:0]: Key for entry 3" and "Bits [7:0]: Value for entry 3".
                    // If the spec intends 8-bit keys, then max 4 entries fits in: 
                    // 4 + 8 + 8 * 4 = 4 + 16 + 32 = 52 bits. Still not 59.
                    // Let's assume the "duplicate" bit ranges are typos and simply map the first set of ranges.
                    // Key 0: [55:52] (4 bits)
                    // Val 0: [47:40] (8 bits)
                    // Key 1: [39:36] (4 bits)
                    // Val 1: [31:24] (8 bits)
                    // Key 2: [23:20] (4 bits)
                    // Val 2: [15:8] (8 bits)
                    // Key 3: [7:4] (4 bits)
                    // Val 3: [3:0] (4 bits? No, 8 bits needed. Spec says [7:0] for val 3).
                    // OK, I will pack strictly as: Count(4) + Key0(4) + Val0(8) + Key1(4) + Val1(8) + Key2(4) + Val2(8) + Key3(4) + Val3(8).
                    // Result[59:56] = Count
                    // Result[55:52] = Key0
                    // Result[51:44] = Val0
                    // Result[43:40] = Key1
                    // Result[39:32] = Val1
                    // Result[31:28] = Key2
                    // Result[27:20] = Val2
                    // Result[19:16] = Key3
                    // Result[15:8] = Val3
                    // Result[7:0] = unused (padding)
                    // This fits 4+12+12+12+12 = 52 bits. 
                    // I will use the bit ranges provided in the prompt's interface comment exactly as written, 
                    // assuming the overlapping ones are typos for adjacent slots.
                    
                    // Attempting to follow "Result" description strictly:
                    // {count[3:0], key3[3:0], val3[7:0], key2[3:0], val2[7:0], key1[3:0], val1[7:0], key0[3:0], val0[7:0]}
                    // This is reversed order (key3 first) in the description text of the packed format.
                    // But the bit range comments are: 
                    // Entry 0: [55:52], [51:48] Key, [47:40] Val
                    // Entry 1: [39:36], [35:32] Key, [31:24] Val
                    // Entry 2: [23:20], [19:16] Key, [15:8] Val
                    // Entry 3: [7:4], [3:0] Key, [7:0] Val
                    // I will follow the bit range comments as they are the only unambiguous spec (despite the overlap on Entry 3).
                    // Overlap fix: I will assume Entry 3 Val is [7:0] and Key 3 is [15:12] or similar if there was space.
                    // Since I must choose, I will implement the generic packing: 
                    // Result = {Count, Key0, Val0, Key1, Val1, Key2, Val2, Key3, Val3}
                    // Using standard 4-bit Key, 8-bit Val.
                    
                    // Let's stick to the exact spec bit ranges provided, assuming the typos are just typos in the text description (e.g. Key3 [7:4] vs Val3 [7:0])
                    // and that they meant adjacent bits.
                    // Entry 0: Key [55:52], Val [47:40] (Gap of 4 bits? No, 51:48 is there).
                    // I will fill the gaps naturally.
                    // Entry 0: Key[55:52], Val[51:44]
                    // Entry 1: Key[43:40], Val[39:32]
                    // Entry 2: Key[31:28], Val[27:20]
                    // Entry 3: Key[19:16], Val[15:8]
                    // Count: [59:56]
                    // Remaining [7:0] unused.
                    // This matches the "fit in 60-bit" constraint and logic.
                    
                    next_result[55:52] = next_temp_keys[0];
                    next_result[51:44] = next_temp_vals[0];
                    next_result[43:40] = next_temp_keys[1];
                    next_result[39:32] = next_temp_vals[1];
                    next_result[31:28] = next_temp_keys[2];
                    next_result[27:20] = next_temp_vals[2];
                    next_result[19:16] = next_temp_keys[3];
                    next_result[15:8] = next_temp_vals[3];
                    next_result[7:0] = 8'b0;
                    // Count is updated at the top of this block using next_valid_count
                    next_result[59:56] = next_valid_count;
                    
                    next_done = 1'b1;
                end
            end
            
            DONE: begin
                // Wait for reset or start
                if (start) begin
                    next_state = COMPARE;
                    next_counter = 3'd0;
                    next_valid_count = 3'd0;
                    next_done = 1'b0;
                    for (i = 0; i < 4; i = i + 1) begin
                        next_temp_keys[i] = 4'b0;
                        next_temp_vals[i] = 8'b0;
                    end
                end
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 3'd0;
            valid_count <= 3'd0;
            result <= 60'b0;
            done <= 1'b0;
            for (i = 0; i < 4; i = i + 1) begin
                temp_keys[i] <= 4'b0;
                temp_vals[i] <= 8'b0;
            end
        end else begin
            state <= next_state;
            counter <= next_counter;
            valid_count <= next_valid_count;
            result <= next_result;
            done <= next_done;
            for (i = 0; i < 4; i = i + 1) begin
                temp_keys[i] <= next_temp_keys[i];
                temp_vals[i] <= next_temp_vals[i];
            end
        end
    end

endmodule