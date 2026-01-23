module remove_occurrences (
    input clk,
    input rst_n,
    input start,
    input [7:0] target_char,
    input [63:0] input_str,
    output reg [63:0] result_str,
    output reg done
);

    // State Encoding
    localparam IDLE        = 4'd0;
    localparam FIND_FIRST  = 4'd1;
    localparam REMOVE_FIRST = 4'd2;
    localparam FIND_LAST   = 4'd3;
    localparam REMOVE_LAST = 4'd4;
    localparam DONE        = 4'd5;

    reg [3:0] current_state;
    reg [3:0] next_state;
    
    reg [63:0] working_str;
    reg [2:0] idx;
    reg [2:0] first_pos;
    reg [2:0] last_pos;
    reg found_first;
    reg found_last;
    
    // Combinational logic for shifting
    wire [63:0] str_after_first_removal;
    wire [63:0] str_after_last_removal;
    
    // Helper function/logic for shift
    // We need to generate the shift for variable position.
    // Using a loop in combinational block is best.
    
    assign str_after_first_removal = shift_left_one_byte(working_str, first_pos);
    assign str_after_last_removal = shift_left_one_byte(working_str, last_pos);

    function automatic [63:0] shift_left_one_byte;
        input [63:0] data_in;
        input [2:0] pos;
        reg [63:0] temp;
        integer i;
        begin
            temp = 64'b0;
            // Copy bytes < pos
            for (i = 0; i < 8; i = i + 1) begin
                if (i < pos) begin
                    temp[i*8 +: 8] = data_in[i*8 +: 8];
                end else if (i < 7) begin
                    // Shift bytes >= pos and < 7 left by one slot
                    temp[i*8 +: 8] = data_in[(i+1)*8 +: 8];
                end
                // Byte 7 effectively becomes 0 (padding), handled by initialization of temp
            end
            shift_left_one_byte = temp;
        end
    endfunction

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next State Logic & Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset outputs and internal states
            done <= 1'b0;
            result_str <= 64'b0;
            working_str <= 64'b0;
            idx <= 3'b0;
            first_pos <= 3'b0;
            last_pos <= 3'b0;
            found_first <= 1'b0;
            found_last <= 1'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        working_str <= input_str;
                        idx <= 3'b0;
                        found_first <= 1'b0;
                        found_last <= 1'b0;
                        // We will search for first occurrence
                        next_state <= FIND_FIRST;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                FIND_FIRST: begin
                    // Iterate idx 0 to 7
                    // We need to check byte at idx.
                    // Since we can't index variable, we use the function logic or combinational extraction.
                    // Or, we can shift the string right (bringing bytes to LSB) to check.
                    // To avoid destroying data, we can use a helper combinational block to get byte `idx`.
                    // Let's use a combinational wire for the current byte.
                    
                    // However, since we are already in a sequential block, let's use a generate block outside to define the byte extraction?
                    // No, simpler: Use the function we defined to check? No, function is for shifting.
                    
                    // Let's assume we add a wire `current_byte`.
                    // But `idx` changes every cycle. 
                    // 
                    // Let's use the trick: We don't need to index if we shift the string.
                    // In FIND_FIRST, we can shift the string right (LSB becomes byte 0) and consume it.
                    // BUT, we need the original string for shifting in REMOVE_FIRST.
                    // So we can't destroy `working_str`.
                    // 
                    // Alternative: 
                    // We have 8 bytes. We can check them by unrolling the if-else in this block.
                    // 
                    // Let's use the `unrolled` check.
                    
                    // Check byte at current idx
                    case (idx)
                        0: if (working_str[7:0] == target_char && !found_first) begin first_pos <= 3'd0; found_first <= 1'b1; end
                        1: if (working_str[15:8] == target_char && !found_first) begin first_pos <= 3'd1; found_first <= 1'b1; end
                        2: if (working_str[23:16] == target_char && !found_first) begin first_pos <= 3'd2; found_first <= 1'b1; end
                        3: if (working_str[31:24] == target_char && !found_first) begin first_pos <= 3'd3; found_first <= 1'b1; end
                        4: if (working_str[39:32] == target_char && !found_first) begin first_pos <= 3'd4; found_first <= 1'b1; end
                        5: if (working_str[47:40] == target_char && !found_first) begin first_pos <= 3'd5; found_first <= 1'b1; end
                        6: if (working_str[55:48] == target_char && !found_first) begin first_pos <= 3'd6; found_first <= 1'b1; end
                        7: if (working_str[63:56] == target_char && !found_first) begin first_pos <= 3'd7; found_first <= 1'b1; end
                    endcase

                    if (idx < 7) begin
                        idx <= idx + 1;
                        next_state <= FIND_FIRST;
                    end else begin
                        idx <= 3'd0; // Reset for next phase
                        next_state <= REMOVE_FIRST;
                    end
                end

                REMOVE_FIRST: begin
                    if (found_first) begin
                        working_str <= str_after_first_removal;
                    end
                    idx <= 3'd0;
                    next_state <= FIND_LAST;
                end

                FIND_LAST: begin
                    // Scan indices 0 to 6 (scan limit 6, so check idx 0..6)
                    // Update last_pos every time match is found.
                    
                    case (idx)
                        0: if (working_str[7:0] == target_char) begin last_pos <= 3'd0; found_last <= 1'b1; end
                        1: if (working_str[15:8] == target_char) begin last_pos <= 3'd1; found_last <= 1'b1; end
                        2: if (working_str[23:16] == target_char) begin last_pos <= 3'd2; found_last <= 1'b1; end
                        3: if (working_str[31:24] == target_char) begin last_pos <= 3'd3; found_last <= 1'b1; end
                        4: if (working_str[39:32] == target_char) begin last_pos <= 3'd4; found_last <= 1'b1; end
                        5: if (working_str[47:40] == target_char) begin last_pos <= 3'd5; found_last <= 1'b1; end
                        6: if (working_str[55:48] == target_char) begin last_pos <= 3'd6; found_last <= 1'b1; end
                    endcase

                    if (idx < 6) begin
                        idx <= idx + 1;
                        next_state <= FIND_LAST;
                    end else begin
                        // idx 6 checked. Next is REMOVE_LAST.
                        next_state <= REMOVE_LAST;
                    end
                end

                REMOVE_LAST: begin
                    if (found_last) begin
                        working_str <= str_after_last_removal;
                        result_str <= str_after_last_removal;
                    end else begin
                        // If last not found (maybe no occurrence after first removal), keep current
                        result_str <= working_str;
                    end
                    done <= 1'b1;
                    next_state <= IDLE; // Go back to idle, done is high
                end
                
                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

endmodule