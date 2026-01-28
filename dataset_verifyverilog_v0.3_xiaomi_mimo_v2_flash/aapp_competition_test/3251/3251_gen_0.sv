module find_longest_sequence (
    input clk,
    input rst_n,
    input start,
    input [7:0] a_in [0:7],
    input [7:0] b_in [0:7],
    input [3:0] num_intervals,
    output reg done,
    output reg [3:0] length,
    output reg [7:0] out_a [0:7],
    output reg [7:0] out_b [0:7]
);

// Parameters
parameter MAX_INTERVALS = 8;
parameter INTERVAL_WIDTH = 8;

// Internal storage
reg [7:0] intervals_a [0:7];
reg [7:0] intervals_b [0:7];
reg [3:0] sorted_idx [0:7];
reg [3:0] dp [0:7];
reg [3:0] prev [0:7];
reg [3:0] best_end;
reg [3:0] state;
reg [3:0] i, j, k;

// States
localparam [3:0] IDLE = 4'd0;
localparam [3:0] LOAD = 4'd1;
localparam [3:0] SORT = 4'd2;
localparam [3:0] DP_INIT = 4'd3;
localparam [3:0] DP_CALC = 4'd4;
localparam [3:0] FIND_BEST = 4'd5;
localparam [3:0] RECONSTRUCT = 4'd6;
localparam [3:0] OUTPUT = 4'd7;
localparam [3:0] DONE = 4'd8;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        done <= 1'b0;
        length <= 4'd0;
        state <= IDLE;
        i <= 4'd0;
        j <= 4'd0;
        k <= 4'd0;
        best_end <= 4'd0;
        // Initialize arrays
        begin : reset_arrays
            integer idx;
            for (idx = 0; idx < 8; idx = idx + 1) begin
                intervals_a[idx] <= 8'd0;
                intervals_b[idx] <= 8'd0;
                sorted_idx[idx] <= 4'd0;
                dp[idx] <= 4'd0;
                prev[idx] <= 4'd0;
                out_a[idx] <= 8'd0;
                out_b[idx] <= 8'd0;
            end
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= LOAD;
                    i <= 4'd0;
                end
            end
            
            LOAD: begin
                if (i < num_intervals && i < MAX_INTERVALS) begin
                    intervals_a[i] <= a_in[i];
                    intervals_b[i] <= b_in[i];
                    sorted_idx[i] <= i;
                    i <= i + 4'd1;
                end else begin
                    state <= SORT;
                    i <= 4'd0;
                    j <= 4'd0;
                end
            end
            
            SORT: begin
                // Bubble sort by A ascending, then B descending
                if (i < num_intervals - 4'd1) begin
                    if (j < num_intervals - i - 4'd1) begin
                        if (intervals_a[sorted_idx[j]] > intervals_a[sorted_idx[j+1]] || 
                            (intervals_a[sorted_idx[j]] == intervals_a[sorted_idx[j+1]] && 
                             intervals_b[sorted_idx[j]] < intervals_b[sorted_idx[j+1]])) begin
                            // Swap
                            sorted_idx[j] <= sorted_idx[j+1];
                            sorted_idx[j+1] <= sorted_idx[j];
                        end
                        j <= j + 4'd1;
                    end else begin
                        i <= i + 4'd1;
                        j <= 4'd0;
                    end
                end else begin
                    state <= DP_INIT;
                    i <= 4'd0;
                end
            end
            
            DP_INIT: begin
                if (i < num_intervals && i < MAX_INTERVALS) begin
                    dp[i] <= 4'd1;
                    prev[i] <= 4'hF; // Invalid marker
                    i <= i + 4'd1;
                end else begin
                    state <= DP_CALC;
                    i <= 4'd0;
                    j <= 4'd0;
                end
            end
            
            DP_CALC: begin
                if (i < num_intervals && i < MAX_INTERVALS) begin
                    if (j < i) begin
                        // Check if interval j contains interval i
                        if (intervals_a[sorted_idx[j]] <= intervals_a[sorted_idx[i]] && 
                            intervals_b[sorted_idx[j]] >= intervals_b[sorted_idx[i]]) begin
                            if (dp[j] + 4'd1 > dp[i]) begin
                                dp[i] <= dp[j] + 4'd1;
                                prev[i] <= j;
                            end
                        end
                        j <= j + 4'd1;
                    end else begin
                        i <= i + 4'd1;
                        j <= 4'd0;
                    end
                end else begin
                    state <= FIND_BEST;
                    i <= 4'd0;
                end
            end
            
            FIND_BEST: begin
                if (i < num_intervals && i < MAX_INTERVALS) begin
                    if (i == 4'd0 || dp[i] > dp[best_end]) begin
                        best_end <= i;
                    end
                    i <= i + 4'd1;
                end else begin
                    state <= RECONSTRUCT;
                    i <= best_end;
                    k <= 4'd0;
                end
            end
            
            RECONSTRUCT: begin
                if (i < 4'd8 && k < 4'd8) begin
                    out_a[k] <= intervals_a[sorted_idx[i]];
                    out_b[k] <= intervals_b[sorted_idx[i]];
                    k <= k + 4'd1;
                    if (prev[i] < 4'd8 && prev[i] != 4'hF) begin
                        i <= prev[i];
                    end else begin
                        state <= OUTPUT;
                        length <= dp[best_end];
                        i <= 4'd0;
                    end
                end else begin
                    state <= OUTPUT;
                    length <= dp[best_end];
                    i <= 4'd0;
                end
            end
            
            OUTPUT: begin
                // Fill remaining outputs with zeros
                if (i < 4'd8) begin
                    if (i >= length) begin
                        out_a[i] <= 8'd0;
                        out_b[i] <= 8'd0;
                    end
                    i <= i + 4'd1;
                end else begin
                    state <= DONE;
                    done <= 1'b1;
                end
            end
            
            DONE: begin
                done <= 1'b0;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule