module max_subarray_swaps #(
    parameter N = 8,
    parameter K = 4,
    parameter DATA_WIDTH = 16,
    parameter FRAC_BITS = 8
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] a [0:N-1],
    input wire [3:0] k,
    output reg [DATA_WIDTH-1:0] max_sum,
    output reg done
);

// State machine encoding
localparam [1:0] IDLE = 2'd0;
localparam [1:0] COMPUTE = 2'd1;
localparam [1:0] UPDATE = 2'd2;
localparam [1:0] FINISHED = 2'd3;

reg [1:0] state;
reg [3:0] l, r;
reg [DATA_WIDTH-1:0] current_max;
reg [DATA_WIDTH-1:0] temp_sum;
reg [3:0] swap_count;
reg [3:0] inner_size;
reg [3:0] outer_size;
reg signed [DATA_WIDTH-1:0] inner_sorted [0:N-1];
reg signed [DATA_WIDTH-1:0] outer_sorted [0:N-1];
reg [3:0] sort_idx;
reg [3:0] swap_idx;

// Helper function for min
function [3:0] min;
    input [3:0] a, b;
    begin
        min = (a < b) ? a : b;
    end
endfunction

// Bubble sort for inner array (ascending)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sort_idx <= 0;
    end else if (state == COMPUTE) begin
        if (sort_idx < inner_size - 1) begin
            if (inner_sorted[sort_idx] > inner_sorted[sort_idx + 1]) begin
                inner_sorted[sort_idx] <= inner_sorted[sort_idx + 1];
                inner_sorted[sort_idx + 1] <= inner_sorted[sort_idx];
            end
            sort_idx <= sort_idx + 1;
        end else begin
            sort_idx <= 0;
        end
    end else if (state == UPDATE) begin
        sort_idx <= 0;
    end
end

// Bubble sort for outer array (descending)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset handled elsewhere
    end else if (state == COMPUTE) begin
        if (sort_idx < outer_size - 1) begin
            if (outer_sorted[sort_idx] < outer_sorted[sort_idx + 1]) begin
                outer_sorted[sort_idx] <= outer_sorted[sort_idx + 1];
                outer_sorted[sort_idx + 1] <= outer_sorted[sort_idx];
            end
        end
    end
end

// Swap comparison logic
integer i;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        swap_count <= 0;
        temp_sum <= 0;
    end else if (state == COMPUTE && sort_idx >= inner_size - 1 && sort_idx >= outer_size - 1) begin
        if (swap_count < min(K, min(inner_size, outer_size))) begin
            if (outer_sorted[swap_count] > inner_sorted[swap_count]) begin
                temp_sum <= temp_sum + (outer_sorted[swap_count] - inner_sorted[swap_count]);
            end
            swap_count <= swap_count + 1;
        end
    end else if (state == UPDATE) begin
        swap_count <= 0;
        temp_sum <= 0;
    end
end

// Main state machine
integer j;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        l <= 0;
        r <= 0;
        current_max <= {DATA_WIDTH{1'b1}}; // Initialize to minimum value
        inner_size <= 0;
        outer_size <= 0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= COMPUTE;
                    l <= 0;
                    r <= 0;
                    current_max <= {DATA_WIDTH{1'b1}};
                end
            end
            
            COMPUTE: begin
                // Extract inner and outer arrays
                if (l == 0 && r == 0) begin
                    for (i = 0; i < N; i = i + 1) begin
                        if (i >= l && i <= r) begin
                            inner_sorted[i] <= a[i];
                        end else begin
                            outer_sorted[i] <= a[i];
                        end
                    end
                    inner_size <= r - l + 1;
                    outer_size <= N - (r - l + 1);
                    sort_idx <= 0;
                    swap_count <= 0;
                    temp_sum <= 0;
                    // Calculate initial sum of inner array
                    for (j = 0; j < N; j = j + 1) begin
                        if (j >= l && j <= r) begin
                            temp_sum <= temp_sum + a[j];
                        end
                    end
                end
                
                // After sorting and swapping completes, move to UPDATE
                if (swap_count >= min(K, min(inner_size, outer_size)) && 
                    sort_idx >= inner_size - 1 && sort_idx >= outer_size - 1) begin
                    state <= UPDATE;
                end
            end
            
            UPDATE: begin
                if (temp_sum > current_max) begin
                    current_max <= temp_sum;
                end
                
                // Move to next subarray
                if (r < N - 1) begin
                    r <= r + 1;
                    state <= COMPUTE;
                end else if (l < N - 2) begin
                    l <= l + 1;
                    r <= l + 1;
                    state <= COMPUTE;
                end else begin
                    state <= FINISHED;
                end
            end
            
            FINISHED: begin
                // Stay here until reset
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule