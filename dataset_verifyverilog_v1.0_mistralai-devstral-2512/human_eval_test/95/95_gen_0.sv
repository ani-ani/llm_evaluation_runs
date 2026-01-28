module uniform_case_checker(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] num_pairs,
    input wire [7:0] key_array [0:7][0:15],
    output reg all_lower,
    output reg all_upper,
    output reg valid,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE  = 2'd0;
    localparam [1:0] CHECK = 2'd1;
    localparam [1:0] DONE  = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [2:0] pair_idx;      // 0-7
    reg [3:0] char_idx;      // 0-15
    reg [7:0] current_char;
    reg mixed_case;
    reg all_keys_lower;
    reg all_keys_upper;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pair_idx <= 3'd0;
            char_idx <= 4'd0;
            current_char <= 8'd0;
            mixed_case <= 1'b0;
            all_keys_lower <= 1'b0;
            all_keys_upper <= 1'b0;
            all_lower <= 1'b0;
            all_upper <= 1'b0;
            valid <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    all_lower <= 1'b0;
                    all_upper <= 1'b0;
                    cycle_count <= 8'd0;
                    
                    if (start) begin
                        next_state <= CHECK;
                        pair_idx <= 3'd0;
                        char_idx <= 4'd0;
                        mixed_case <= 1'b0;
                        all_keys_lower <= 1'b1;  // Assume all lower initially
                        all_keys_upper <= 1'b1;  // Assume all upper initially
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Get current character
                    current_char <= key_array[pair_idx][char_idx];
                    
                    // Check if we've processed all pairs
                    if (pair_idx == num_pairs - 1 && char_idx == 4'd0) begin
                        next_state <= DONE;
                    end
                    // Move to next character or next pair
                    else if (char_idx == 4'd15 || current_char == 8'd0) begin
                        char_idx <= 4'd0;
                        pair_idx <= pair_idx + 3'd1;
                    end else begin
                        char_idx <= char_idx + 4'd1;
                    end
                    
                    // Check character case
                    if (current_char != 8'd0) begin
                        if (current_char >= 8'd65 && current_char <= 8'd90) begin
                            // Uppercase
                            all_keys_lower <= 1'b0;
                        end else if (current_char >= 8'd97 && current_char <= 8'd122) begin
                            // Lowercase
                            all_keys_upper <= 1'b0;
                        end else begin
                            // Invalid character - mark as mixed
                            mixed_case <= 1'b1;
                        end
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE;
                    end
                end

                DONE: begin
                    // Determine final outputs
                    if (num_pairs == 4'd0) begin
                        valid <= 1'b0;
                        all_lower <= 1'b0;
                        all_upper <= 1'b0;
                    end else if (mixed_case) begin
                        valid <= 1'b0;
                        all_lower <= 1'b0;
                        all_upper <= 1'b0;
                    end else begin
                        valid <= 1'b1;
                        all_lower <= all_keys_lower;
                        all_upper <= all_keys_upper;
                    end
                    
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    valid <= 1'b0;
                    all_lower <= 1'b0;
                    all_upper <= 1'b0;
                end
            endcase
        end
    end

endmodule