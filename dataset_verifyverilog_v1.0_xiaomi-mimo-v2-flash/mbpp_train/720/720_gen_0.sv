module fixed_width_concat (
    input clk,
    input rst_n,
    input start,
    input [15:0] tuple_in [0:3],
    input [7:0] dict_keys [0:2],
    input [7:0] dict_vals [0:2],
    output reg [15:0] result [0:4],
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] PACK_DICT = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    reg [1:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Pipeline registers for tuple elements
    reg [15:0] tuple_reg [0:3];
    reg [7:0] keys_reg [0:2];
    reg [7:0] vals_reg [0:2];

    // Intermediate packed dictionary data
    reg [15:0] packed_dict;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
            // Initialize all result registers
            result[0] <= 16'd0;
            result[1] <= 16'd0;
            result[2] <= 16'd0;
            result[3] <= 16'd0;
            result[4] <= 16'd0;
            // Initialize pipeline registers
            tuple_reg[0] <= 16'd0;
            tuple_reg[1] <= 16'd0;
            tuple_reg[2] <= 16'd0;
            tuple_reg[3] <= 16'd0;
            keys_reg[0] <= 8'd0;
            keys_reg[1] <= 8'd0;
            keys_reg[2] <= 8'd0;
            vals_reg[0] <= 8'd0;
            vals_reg[1] <= 8'd0;
            vals_reg[2] <= 8'd0;
            packed_dict <= 16'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    // Keep result registers at 0 when idle
                    result[0] <= 16'd0;
                    result[1] <= 16'd0;
                    result[2] <= 16'd0;
                    result[3] <= 16'd0;
                    result[4] <= 16'd0;
                    if (start) begin
                        // Capture input data to pipeline registers
                        tuple_reg[0] <= tuple_in[0];
                        tuple_reg[1] <= tuple_in[1];
                        tuple_reg[2] <= tuple_in[2];
                        tuple_reg[3] <= tuple_in[3];
                        keys_reg[0] <= dict_keys[0];
                        keys_reg[1] <= dict_keys[1];
                        keys_reg[2] <= dict_keys[2];
                        vals_reg[0] <= dict_vals[0];
                        vals_reg[1] <= dict_vals[1];
                        vals_reg[2] <= dict_vals[2];
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Pipeline stage 1: Assign tuple elements directly to result
                    result[0] <= tuple_reg[0];
                    result[1] <= tuple_reg[1];
                    result[2] <= tuple_reg[2];
                    result[3] <= tuple_reg[3];
                    // Prepare packed dictionary in next cycle
                end
                
                PACK_DICT: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Pack all 3 keys and 3 values into 16-bit word
                    // Format: keys[7:0], vals[7:0] for each pair
                    // We pack key0/val0 into lower 8 bits each, then key1/val1, etc.
                    // But spec says: "keys[7:0], vals[7:0] (lower 8 bits = key0, next 8 bits = val0)"
                    // This implies a single 16-bit value with key0 in lower 8 bits and val0 in upper 8 bits?
                    // Wait, re-reading: "pack all 3 keys and 3 values into 16-bit word"
                    // 6 values into 16 bits? That's 2.66 bits per value. 
                    // Let's interpret: Pack as key0|val0 (8+8=16 bits)
                    // But we have 3 keys and 3 values. This is ambiguous.
                    // Most likely: Pack all into one 16-bit word somehow, or concatenate.
                    // Given 16-bit width, and 6x8-bit inputs, we need to pack 2 per 16-bit slot.
                    // But spec says "result[4]" gets packed dict data. Only ONE 16-bit slot.
                    // With 6x8-bit inputs, we need 48 bits total. 
                    // Maybe the format is: keys[0], vals[0] in first 16 bits? No, that's one element.
                    // Let's re-read: "Pack format: keys[7:0], vals[7:0] (lower 8 bits = key0, next 8 bits = val0)"
                    // This seems to describe a single pair. But we have 3 pairs.
                    // Maybe the spec implies only the first key/val pair goes into result[4]?
                    // OR: "pack all 3 keys and 3 values" means: key0|val0, key1|val1, key2|val2? 
                    // But result is only 5 elements. Tuple is 4. Dict is result[4].
                    // This implies result[4] must hold all 6 bytes.
                    // Since 6*8=48 bits > 16 bits, this is impossible to fit in a single 16-bit word.
                    // Interpretation 2: The "16-bit word" is just the data type. 
                    // Maybe result[4] is just one 16-bit value, and we take only the first pair?
                    // Interpretation 3: The prompt has a mistake and meant result[4] is 48-bit? 
                    // Or maybe `result` is `packed`? "result[0:4][15:0]" means 5 distinct 16-bit values.
                    // Given the strict "16-bit word" for result[4], I will pack only the first key/val pair
                    // as specified in the format description: key0 in lower 8 bits, val0 in next 8 bits.
                    // This fits in 16 bits (though 16 bits usually means [15:0]).
                    // Wait, "next 8 bits" implies [15:8]. 
                    // packed_dict[7:0] = keys_reg[0];
                    // packed_dict[15:8] = vals_reg[0];
                    // This matches "keys[7:0], vals[7:0]" format exactly for one pair.
                    packed_dict <= {vals_reg[0], keys_reg[0]};
                    result[4] <= {vals_reg[0], keys_reg[0]};
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESS;
                end else begin
                    next_state = IDLE;
                end
            end
            
            PROCESS: begin
                // 2-cycle latency requirement
                // PROCESS -> PACK_DICT (1 cycle)
                // PACK_DICT -> FINISH (1 cycle)
                next_state = PACK_DICT;
            end
            
            PACK_DICT: begin
                next_state = FINISH;
            end
            
            FINISH: begin
                // Return to IDLE immediately after 1 cycle pulse
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule