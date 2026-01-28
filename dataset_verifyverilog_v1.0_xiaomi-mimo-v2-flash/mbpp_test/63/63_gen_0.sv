module FindMaxAbsDiff(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] pairs_in,
    input wire [3:0] valid_pairs,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE   = 2'd0;
    localparam [1:0] CALC   = 2'd1;
    localparam [1:0] UPDATE = 2'd2;
    localparam [1:0] DONE   = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg [3:0] pair_index;      // 0-7 for pairs
    reg [7:0] max_diff;        // Track current maximum difference (0-255)
    reg [7:0] diff_reg;        // Pipeline register for difference
    reg [15:0] temp_result;    // Accumulate final result
    reg processing;            // Flag for active computation

    // Extract pair elements from packed array
    wire signed [7:0] elem_a;
    wire signed [7:0] elem_b;
    wire [7:0] abs_diff;

    // Extract current pair based on pair_index
    // pairs_in[7:0] = pair 0, pairs_in[15:8] = pair 1, etc.
    assign elem_a = pairs_in[7 + pair_index*8 +: 8];
    assign elem_b = pairs_in[7 + pair_index*8 + 8 +: 8];
    
    // Compute absolute difference (always positive)
    wire signed [8:0] diff_signed;
    assign diff_signed = elem_a - elem_b;  // 9-bit signed
    assign abs_diff = (diff_signed[8]) ? -diff_signed[7:0] : diff_signed[7:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            pair_index <= 4'd0;
            max_diff <= 8'd0;
            diff_reg <= 8'd0;
            temp_result <= 16'd0;
            processing <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    max_diff <= 8'd0;
                    pair_index <= 4'd0;
                    processing <= 1'b0;
                    
                    if (start) begin
                        if (valid_pairs == 4'd0) begin
                            // Edge case: no valid pairs
                            temp_result <= 16'd0;
                            state <= DONE;
                        end else begin
                            processing <= 1'b1;
                            state <= CALC;
                        end
                    end
                end
                
                CALC: begin
                    // Compute difference for current pair
                    diff_reg <= abs_diff;
                    
                    // Move to update state
                    state <= UPDATE;
                end
                
                UPDATE: begin
                    // Update maximum difference
                    if (diff_reg > max_diff) begin
                        max_diff <= diff_reg;
                    end
                    
                    // Check if all valid pairs processed
                    if (pair_index >= valid_pairs - 1'b1) begin
                        // All pairs processed
                        temp_result <= {8'd0, max_diff};  // Extend to 16 bits
                        state <= DONE;
                    end else begin
                        // Process next pair
                        pair_index <= pair_index + 4'd1;
                        state <= CALC;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    result <= temp_result;
                    state <= IDLE;
                    processing <= 1'b0;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule