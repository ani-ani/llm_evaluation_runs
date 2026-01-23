module rectangle_fix (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    input wire [7:0] m,
    input wire [3:0] k,
    input wire [99:0] matrix [0:99],
    output reg [7:0] result,
    output reg done
);
    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] TRANSPOSE = 3'd1;
    localparam [2:0] CONVERT = 3'd2;
    localparam [2:0] PREP_CAND = 3'd3;
    localparam [2:0] COMPUTE = 3'd4;
    localparam [2:0] DONE = 3'd5;
    
    reg [2:0] state;
    
    // Internal storage
    reg [99:0] transposed [0:99];
    reg [7:0] new_n;
    reg [7:0] new_m;
    reg [99:0] row_val [0:99];
    reg [99:0] candidates [0:199];
    reg [7:0] num_candidates;
    reg [99:0] candidate;
    reg [7:0] min_total;
    
    // Loop counters
    integer i;
    integer j;
    integer cand_idx;
    integer row_idx;
    
    // Popcount function
    function [7:0] popcount;
        input [99:0] vec;
        integer k;
        begin
            popcount = 8'd0;
            for (k = 0; k < 100; k = k + 1) begin
                if (vec[k]) popcount = popcount + 8'd1;
            end
        end
    endfunction
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'd0;
            new_n <= 8'd0;
            new_m <= 8'd0;
            num_candidates <= 8'd0;
            min_total <= 8'd0;
            cand_idx <= 0;
            row_idx <= 0;
            // Initialize arrays
            for (i = 0; i < 100; i = i + 1) begin
                transposed[i] <= 100'd0;
                row_val[i] <= 100'd0;
            end
            for (i = 0; i < 200; i = i + 1) begin
                candidates[i] <= 100'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= TRANSPOSE;
                    end
                end
                
                TRANSPOSE: begin
                    if (n < m) begin
                        // Transpose matrix
                        for (i = 0; i < 100; i = i + 1) begin
                            for (j = 0; j < 100; j = j + 1) begin
                                transposed[j][99-i] <= matrix[i][99-j];
                            end
                        end
                        new_n <= m;
                        new_m <= n;
                    end else begin
                        for (i = 0; i < 100; i = i + 1) begin
                            transposed[i] <= matrix[i];
                        end
                        new_n <= n;
                        new_m <= m;
                    end
                    state <= CONVERT;
                end
                
                CONVERT: begin
                    // Convert rows to bit masks (MSB first)
                    if (row_idx < new_n) begin
                        row_val[row_idx] <= 100'd0;
                        for (j = 0; j < new_m; j = j + 1) begin
                            row_val[row_idx] <= {row_val[row_idx][98:0], transposed[row_idx][99-j]};
                        end
                        row_idx <= row_idx + 1;
                    end else begin
                        row_idx <= 0;
                        state <= PREP_CAND;
                    end
                end
                
                PREP_CAND: begin
                    if (new_m <= k) begin
                        num_candidates <= 1 << new_m;
                    end else begin
                        if (row_idx < new_n) begin
                            candidates[num_candidates] <= row_val[row_idx];
                            num_candidates <= num_candidates + 8'd1;
                            candidates[num_candidates + 8'd1] <= (~row_val[row_idx]) & ((1 << new_m) - 1);
                            num_candidates <= num_candidates + 8'd2;
                            row_idx <= row_idx + 1;
                        end else begin
                            state <= COMPUTE;
                            min_total <= 8'hFF;
                            cand_idx <= 0;
                        end
                    end
                end
                
                COMPUTE: begin
                    if (cand_idx < num_candidates) begin
                        // Get candidate pattern
                        if (new_m <= k)
                            candidate <= cand_idx;
                        else
                            candidate <= candidates[cand_idx];
                        
                        // Calculate total flips for this candidate
                        // This is a simplified version - actual implementation
                        // would need to accumulate across all rows
                        reg [7:0] total_flips;
                        total_flips = 8'd0;
                        for (row_idx = 0; row_idx < new_n; row_idx = row_idx + 1) begin
                            reg [99:0] diff;
                            reg [7:0] c;
                            reg [7:0] flips;
                            diff = row_val[row_idx] ^ candidate;
                            c = popcount(diff);
                            flips = (c < (new_m - c)) ? c : (new_m - c);
                            total_flips = total_flips + flips;
                        end
                        
                        if (total_flips < min_total)
                            min_total <= total_flips;
                        
                        cand_idx <= cand_idx + 1;
                    end else begin
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    if (min_total <= k && min_total != 8'hFF)
                        result <= min_total;
                    else
                        result <= 8'hFF;  // Represents -1
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule