module spec_frequency_lists(
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Input array: flattened list of max 12 elements (3 sublists of 4 elements each)
    // Using individual ports for easier assignment
    input wire [7:0] arr_0, arr_1, arr_2, arr_3,
    input wire [7:0] arr_4, arr_5, arr_6, arr_7,
    input wire [7:0] arr_8, arr_9, arr_10, arr_11,
    input wire [3:0] num_elements,  // 1 to 12
    
    // Output: 2D array of (value, count) pairs
    // We output up to 12 pairs (worst case: all unique)
    output reg [7:0] out_val_0, out_val_1, out_val_2, out_val_3,
    output reg [7:0] out_val_4, out_val_5, out_val_6, out_val_7,
    output reg [7:0] out_val_8, out_val_9, out_val_10, out_val_11,
    output reg [3:0] out_count_0, out_count_1, out_count_2, out_count_3,
    output reg [3:0] out_count_4, out_count_5, out_count_6, out_count_7,
    output reg [3:0] out_count_8, out_count_9, out_count_10, out_count_11,
    output reg [3:0] out_num_pairs,  // Number of valid (value, count) pairs
    
    output reg done
);

    // State machine states
    localparam [2:0] S_IDLE = 3'b000;
    localparam [2:0] S_GATHER = 3'b001;  // Collect unique values
    localparam [2:0] S_COMPARE = 3'b010; // Compare for uniqueness
    localparam [2:0] S_COUNT = 3'b011;   // Count frequencies
    localparam [2:0] S_OUTPUT = 3'b100; // Prepare output
    localparam [2:0] S_DONE = 3'b101;
    
    reg [2:0] state;
    reg [3:0] idx;           // Index for iterating through input array
    reg [3:0] pair_idx;      // Index for unique pairs found
    reg [3:0] scan_idx;      // Index for counting loop
    reg [3:0] compare_idx;   // Index for comparison loop
    
    // Storage for unique values (max 12)
    reg [7:0] unique_vals [0:11];
    reg [3:0] counts [0:11];
    
    // Temp registers for comparison
    reg found;
    reg [7:0] current_val;
    
    integer k;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 1'b0;
            idx <= 4'd0;
            pair_idx <= 4'd0;
            scan_idx <= 4'd0;
            compare_idx <= 4'd0;
            out_num_pairs <= 4'd0;
            // Reset outputs
            out_val_0 <= 8'd0; out_val_1 <= 8'd0; out_val_2 <= 8'd0; out_val_3 <= 8'd0;
            out_val_4 <= 8'd0; out_val_5 <= 8'd0; out_val_6 <= 8'd0; out_val_7 <= 8'd0;
            out_val_8 <= 8'd0; out_val_9 <= 8'd0; out_val_10 <= 8'd0; out_val_11 <= 8'd0;
            out_count_0 <= 4'd0; out_count_1 <= 4'd0; out_count_2 <= 4'd0; out_count_3 <= 4'd0;
            out_count_4 <= 4'd0; out_count_5 <= 4'd0; out_count_6 <= 4'd0; out_count_7 <= 4'd0;
            out_count_8 <= 4'd0; out_count_9 <= 4'd0; out_count_10 <= 4'd0; out_count_11 <= 4'd0;
            for (k = 0; k < 12; k = k + 1) begin
                unique_vals[k] <= 8'd0;
                counts[k] <= 4'd0;
            end
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    idx <= 4'd0;
                    pair_idx <= 4'd0;
                    scan_idx <= 4'd0;
                    compare_idx <= 4'd0;
                    out_num_pairs <= 4'd0;
                    if (start && num_elements > 4'd0) begin
                        state <= S_GATHER;
                    end
                end
                
                S_GATHER: begin
                    if (idx < num_elements) begin
                        // Get input value based on idx
                        case (idx)
                            4'd0: current_val <= arr_0;
                            4'd1: current_val <= arr_1;
                            4'd2: current_val <= arr_2;
                            4'd3: current_val <= arr_3;
                            4'd4: current_val <= arr_4;
                            4'd5: current_val <= arr_5;
                            4'd6: current_val <= arr_6;
                            4'd7: current_val <= arr_7;
                            4'd8: current_val <= arr_8;
                            4'd9: current_val <= arr_9;
                            4'd10: current_val <= arr_10;
                            4'd11: current_val <= arr_11;
                            default: current_val <= 8'd0;
                        endcase
                        
                        // Store current value temporarily
                        unique_vals[pair_idx] <= current_val;
                        compare_idx <= 4'd0;
                        found <= 1'b0;
                        state <= S_COMPARE;
                        idx <= idx + 4'd1;
                    end else begin
                        // All elements processed, go to counting
                        state <= S_COUNT;
                        scan_idx <= 4'd0;
                    end
                end
                
                S_COMPARE: begin
                    if (compare_idx < pair_idx) begin
                        if (unique_vals[compare_idx] == current_val) begin
                            found <= 1'b1;
                        end
                        compare_idx <= compare_idx + 4'd1;
                    end else begin
                        // Finished comparing
                        if (!found) begin
                            // New unique value, increment pair_idx
                            pair_idx <= pair_idx + 4'd1;
                        end
                        state <= S_GATHER;
                    end
                end
                
                S_COUNT: begin
                    if (scan_idx < pair_idx) begin
                        // Reset count for this value
                        counts[scan_idx] <= 4'd0;
                        idx <= 4'd0;
                        state <= 3'b110; // Counting scan state
                    end else begin
                        // Counting done, prepare output
                        out_num_pairs <= pair_idx;
                        state <= S_OUTPUT;
                    end
                end
                
                3'b110: begin // Inner counting loop
                    if (idx < num_elements) begin
                        // Get current input value
                        case (idx)
                            4'd0: if (arr_0 == unique_vals[scan_idx]) counts[scan_idx] <= counts[scan_idx] + 4'd1;
                            4'd1: if (arr_1 == unique_vals[scan_idx]) counts[scan_idx] <= counts[scan_idx] + 4'd1;
                            4'd2: if (arr_2 == unique_vals[scan_idx]) counts[scan_idx] <= counts[scan_idx] + 4'd1;
                            4'd3: if (arr_3 == unique_vals[scan_idx]) counts[scan_idx] <= counts[scan_idx] + 4'd1;
                            4'd4: if (arr_4 == unique_vals[scan_idx]) counts[scan_idx] <= counts[scan_idx] + 4'd1;
                            4'd5: if (arr_5 == unique_vals[scan_idx]) counts[scan_idx] <= counts[scan_idx] + 4'd1;
                            4'd6: if (arr_6 == unique_vals[scan_idx]) counts[scan_idx] <= counts[scan_idx] + 4'd1;
                            4'd7: if (arr_7 == unique_vals[scan_idx]) counts[scan_idx] <= counts[scan_idx] + 4'd1;
                            4'd8: if (arr_8 == unique_vals[scan_idx]) counts[scan_idx] <= counts[scan_idx] + 4'd1;
                            4'd9: if (arr_9 == unique_vals[scan_idx]) counts[scan_idx] <= counts[scan_idx] + 4'd1;
                            4'd10: if (arr_10 == unique_vals[scan_idx]) counts[scan_idx] <= counts[scan_idx] + 4'd1;
                            4'd11: if (arr_11 == unique_vals[scan_idx]) counts[scan_idx] <= counts[scan_idx] + 4'd1;
                        endcase
                        idx <= idx + 4'd1;
                    end else begin
                        // Done counting this value
                        scan_idx <= scan_idx + 4'd1;
                        state <= S_COUNT;
                    end
                end
                
                S_OUTPUT: begin
                    // Copy to outputs
                    out_val_0 <= unique_vals[0]; out_count_0 <= counts[0];
                    out_val_1 <= unique_vals[1]; out_count_1 <= counts[1];
                    out_val_2 <= unique_vals[2]; out_count_2 <= counts[2];
                    out_val_3 <= unique_vals[3]; out_count_3 <= counts[3];
                    out_val_4 <= unique_vals[4]; out_count_4 <= counts[4];
                    out_val_5 <= unique_vals[5]; out_count_5 <= counts[5];
                    out_val_6 <= unique_vals[6]; out_count_6 <= counts[6];
                    out_val_7 <= unique_vals[7]; out_count_7 <= counts[7];
                    out_val_8 <= unique_vals[8]; out_count_8 <= counts[8];
                    out_val_9 <= unique_vals[9]; out_count_9 <= counts[9];
                    out_val_10 <= unique_vals[10]; out_count_10 <= counts[10];
                    out_val_11 <= unique_vals[11]; out_count_11 <= counts[11];
                    state <= S_DONE;
                end
                
                S_DONE: begin
                    done <= 1'b1;
                    state <= S_IDLE;
                end
                
                default: state <= S_IDLE;
            endcase
        end
    end

endmodule