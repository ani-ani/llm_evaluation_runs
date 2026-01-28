module SubstringRotationCheck (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] len_a,
    input wire [3:0] len_b,
    input wire [7:0] a [0:15],
    input wire [7:0] b [0:15],
    output reg result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] CHECK_LEN    = 3'd1;
    localparam [2:0] SET_ROTATION = 3'd2;
    localparam [2:0] COMPARE      = 3'd3;
    localparam [2:0] MATCH_FOUND  = 3'd4;
    localparam [2:0] FINISH       = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] rotation_idx;      // Current rotation (0 to len_b-1)
    reg [3:0] a_pos;             // Position in string A to compare
    reg [3:0] b_idx;             // Index in string B (for rotation)
    reg [3:0] match_len;         // Number of matched characters
    reg [7:0] a_char, b_char;    // Current characters for comparison
    reg comparison_done;         // Flag for comparison completion
    reg found_match;             // Flag for match found
    reg [7:0] cycle_counter;     // Safety cycle counter

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            rotation_idx <= 4'd0;
            a_pos <= 4'd0;
            b_idx <= 4'd0;
            match_len <= 4'd0;
            a_char <= 8'd0;
            b_char <= 8'd0;
            comparison_done <= 1'b0;
            found_match <= 1'b0;
            cycle_counter <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    cycle_counter <= 8'd0;
                    if (start) begin
                        rotation_idx <= 4'd0;
                        found_match <= 1'b0;
                        state <= CHECK_LEN;
                    end
                end

                CHECK_LEN: begin
                    // Check if len_b is valid and less than or equal to len_a
                    if (len_b == 4'd0 || len_a < len_b) begin
                        // No possible match
                        state <= FINISH;
                    end else begin
                        a_pos <= 4'd0;
                        state <= SET_ROTATION;
                    end
                end

                SET_ROTATION: begin
                    // Set up for current rotation
                    match_len <= 4'd0;
                    comparison_done <= 1'b0;
                    cycle_counter <= cycle_counter + 8'd1;
                    state <= COMPARE;
                end

                COMPARE: begin
                    // Character-by-character comparison
                    if (!comparison_done && cycle_counter < 8'd250) begin
                        cycle_counter <= cycle_counter + 8'd1;
                        
                        if (match_len < len_b) begin
                            // Calculate b index for rotation
                            b_idx <= (match_len + rotation_idx) % len_b;
                            // Get characters
                            a_char <= a[a_pos + match_len];
                            b_char <= b[b_idx];
                            
                            if (a[a_pos + match_len] == b[b_idx]) begin
                                match_len <= match_len + 4'd1;
                            end else begin
                                // Mismatch at this position
                                match_len <= 4'd0;
                                a_pos <= a_pos + 4'd1;
                                
                                // Check if we've exhausted all positions in A
                                if (a_pos >= len_a - len_b + 4'd1) begin
                                    // No match for this rotation
                                    comparison_done <= 1'b1;
                                end
                            end
                        end else begin
                            // Full match found
                            comparison_done <= 1'b1;
                            found_match <= 1'b1;
                            state <= MATCH_FOUND;
                        end
                    end else if (comparison_done && !found_match) begin
                        // No match for this rotation, try next rotation
                        if (rotation_idx < len_b - 4'd1) begin
                            rotation_idx <= rotation_idx + 4'd1;
                            a_pos <= 4'd0;
                            state <= SET_ROTATION;
                        end else begin
                            // All rotations checked, no match
                            state <= FINISH;
                        end
                    end else if (found_match) begin
                        state <= MATCH_FOUND;
                    end
                end

                MATCH_FOUND: begin
                    // Found a match
                    result <= 1'b1;
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule