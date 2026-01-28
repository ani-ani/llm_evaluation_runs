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
    
    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] TRANSPOSE = 3'd1;
    localparam [2:0] CONVERT = 3'd2;
    localparam [2:0] PREP_CAND = 3'd3;
    localparam [2:0] COMPUTE = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;
    
    reg [2:0] state, next_state;
    
    // Internal storage
    reg [99:0] transposed [0:99];
    reg [7:0] new_n, new_m;
    reg [99:0] row_val [0:99];
    reg [99:0] candidates [0:199];
    reg [7:0] num_candidates;
    reg [99:0] candidate;
    reg [7:0] min_total;
    
    // Loop counters
    reg [7:0] i, j, cand_idx;
    
    // Popcount function
    function [7:0] popcount;
        input [99:0] vec;
        integer k;
        begin
            popcount = 8'd0;
            for (k = 0; k < 100; k = k + 1)
                if (vec[k]) popcount = popcount + 8'd1;
        end
    endfunction
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = TRANSPOSE;
                else
                    next_state = IDLE;
            end
            
            TRANSPOSE: next_state = CONVERT;
            
            CONVERT: next_state = PREP_CAND;
            
            PREP_CAND: next_state = COMPUTE;
            
            COMPUTE: begin
                if (cand_idx < num_candidates)
                    next_state = COMPUTE;
                else
                    next_state = DONE_STATE;
            end
            
            DONE_STATE: begin
                if (!start)
                    next_state = IDLE;
                else
                    next_state = DONE_STATE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'd0;
            
            // Initialize all registers
            new_n <= 8'd0;
            new_m <= 8'd0;
            min_total <= 8'd0;
            num_candidates <= 8'd0;
            cand_idx <= 8'd0;
            i <= 8'd0;
            j <= 8'd0;
            
            // Initialize arrays
            integer idx;
            for (idx = 0; idx < 100; idx = idx + 1) begin
                transposed[idx] <= 100'd0;
                row_val[idx] <= 100'd0;
            end
            
            for (idx = 0; idx < 200; idx = idx + 1) begin
                candidates[idx] <= 100'd0;
            end
        end else begin
            state <= next_state;
        end
    end
    
    // Main logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already initialized above
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 8'd0;
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
                end
                
                CONVERT: begin
                    // Convert rows to bit masks (MSB first)
                    for (i = 0; i < new_n; i = i + 1) begin
                        row_val[i] <= 100'd0;
                        for (j = 0; j < new_m; j = j + 1) begin
                            row_val[i] <= {row_val[i][98:0], transposed[i][99-j]};
                        end
                    end
                end
                
                PREP_CAND: begin
                    if (new_m <= k) begin
                        num_candidates <= 1 << new_m;
                    end else begin
                        num_candidates <= 8'd0;
                        for (i = 0; i < new_n; i = i + 1) begin
                            candidates[num_candidates] <= row_val[i];
                            num_candidates <= num_candidates + 8'd1;
                            candidates[num_candidates] <= ~row_val[i] & ((1 << new_m) - 1);
                            num_candidates <= num_candidates + 8'd1;
                        end
                    end
                    min_total <= 8'hFF;
                    cand_idx <= 8'd0;
                end
                
                COMPUTE: begin
                    if (cand_idx < num_candidates) begin
                        // Get candidate pattern
                        if (new_m <= k)
                            candidate <= cand_idx;
                        else
                            candidate <= candidates[cand_idx];
                        
                        // Calculate total flips for this candidate
                        reg [7:0] total_flips = 8'd0;
                        for (i = 0; i < new_n; i = i + 1) begin
                            reg [99:0] diff = row_val[i] ^ candidate;
                            reg [7:0] c = popcount(diff);
                            reg [7:0] flips = (c < (new_m - c)) ? c : (new_m - c);
                            total_flips <= total_flips + flips;
                        end
                        
                        // Update min_total
                        if (total_flips < min_total)
                            min_total <= total_flips;
                        
                        cand_idx <= cand_idx + 8'd1;
                    end
                end
                
                DONE_STATE: begin
                    if (min_total <= k && min_total != 8'hFF)
                        result <= min_total;
                    else
                        result <= 8'hFF;  // Represents -1
                    done <= 1'b1;
                end
            endcase
        end
    end
endmodule