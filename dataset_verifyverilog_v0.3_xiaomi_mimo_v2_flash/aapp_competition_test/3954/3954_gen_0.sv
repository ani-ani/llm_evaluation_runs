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
    output wire [DATA_WIDTH-1:0] max_sum,
    output wire done
);

// State machine encoding
localparam [2:0] IDLE = 3'd0;
localparam [2:0] COMPUTE = 3'd1;
localparam [2:0] SORT_INNER = 3'd2;
localparam [2:0] SORT_OUTER = 3'd3;
localparam [2:0] SWAP = 3'd4;
localparam [2:0] UPDATE = 3'd5;
localparam [2:0] FINISHED = 3'd6;

reg [2:0] state;
reg [2:0] next_state;
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
reg [7:0] cycle_count;
localparam [7:0] MAX_CYCLES = 8'd200;

// Helper function for min
function [3:0] min;
    input [3:0] a, b;
    begin
        min = (a < b) ? a : b;
    end
endfunction

// Extract arrays from input and compute initial sum
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (integer i = 0; i < N; i = i + 1) begin
            inner_sorted[i] <= 0;
            outer_sorted[i] <= 0;
        end
        inner_size <= 0;
        outer_size <= 0;
        temp_sum <= 0;
    end else if (state == COMPUTE && next_state == SORT_INNER) begin
        // Extract and initialize
        for (integer i = 0; i < N; i = i + 1) begin
            if (i >= l && i <= r) begin
                inner_sorted[i] <= a[i];
            end else begin
                outer_sorted[i] <= a[i];
            end
        end
        inner_size <= r - l + 1;
        outer_size <= N - (r - l + 1);
        // Calculate initial sum
        temp_sum <= 0;
        for (integer j = 0; j < N; j = j + 1) begin
            if (j >= l && j <= r) begin
                temp_sum <= temp_sum + a[j];
            end
        end
    end else if (state == UPDATE) begin
        temp_sum <= 0;
    end
end

// Bubble sort for inner array (ascending)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sort_idx <= 0;
    end else if (state == SORT_INNER) begin
        if (sort_idx < inner_size - 1) begin
            if (inner_sorted[sort_idx] > inner_sorted[sort_idx + 1]) begin
                inner_sorted[sort_idx] <= inner_sorted[sort_idx + 1];
                inner_sorted[sort_idx + 1] <= inner_sorted[sort_idx];
            end
            sort_idx <= sort_idx + 1;
        end else begin
            sort_idx <= 0;
        end
    end else if (state == SORT_OUTER) begin
        sort_idx <= 0;
    end else if (state == UPDATE) begin
        sort_idx <= 0;
    end
end

// Bubble sort for outer array (descending)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset handled elsewhere
    end else if (state == SORT_OUTER) begin
        if (sort_idx < outer_size - 1) begin
            if (outer_sorted[sort_idx] < outer_sorted[sort_idx + 1]) begin
                outer_sorted[sort_idx] <= outer_sorted[sort_idx + 1];
                outer_sorted[sort_idx + 1] <= outer_sorted[sort_idx];
            end
        end
    end
end

// Swap comparison logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        swap_count <= 0;
        swap_idx <= 0;
    end else if (state == SWAP) begin
        if (swap_count < min(K, min(inner_size, outer_size))) begin
            if (outer_sorted[swap_idx] > inner_sorted[swap_idx]) begin
                temp_sum <= temp_sum + (outer_sorted[swap_idx] - inner_sorted[swap_idx]);
            end
            swap_idx <= swap_idx + 1;
            swap_count <= swap_count + 1;
        end
    end else if (state == UPDATE) begin
        swap_count <= 0;
        swap_idx <= 0;
    end
end

// Combinational next state logic
always @(*) begin
    case (state)
        IDLE: begin
            if (start) begin
                next_state = COMPUTE;
            end else begin
                next_state = IDLE;
            end
        end
        COMPUTE: begin
            next_state = SORT_INNER;
        end
        SORT_INNER: begin
            if (sort_idx >= inner_size - 1) begin
                next_state = SORT_OUTER;
            end else begin
                next_state = SORT_INNER;
            end
        end
        SORT_OUTER: begin
            if (sort_idx >= outer_size - 1) begin
                next_state = SWAP;
            end else begin
                next_state = SORT_OUTER;
            end
        end
        SWAP: begin
            if (swap_count >= min(K, min(inner_size, outer_size))) begin
                next_state = UPDATE;
            end else begin
                next_state = SWAP;
            end
        end
        UPDATE: begin
            if (r < N - 1) begin
                next_state = COMPUTE;
            end else if (l < N - 2) begin
                next_state = COMPUTE;
            end else begin
                next_state = FINISHED;
            end
        end
        FINISHED: begin
            next_state = FINISHED;
        end
        default: next_state = IDLE;
    endcase
end

// Main state machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        l <= 0;
        r <= 0;
        current_max <= {DATA_WIDTH{1'b0}};
        cycle_count <= 0;
    end else begin
        state <= next_state;
        cycle_count <= cycle_count + 8'd1;
        
        case (state)
            IDLE: begin
                cycle_count <= 0;
                l <= 0;
                r <= 0;
                current_max <= {DATA_WIDTH{1'b0}};
            end
            
            UPDATE: begin
                if (temp_sum > current_max) begin
                    current_max <= temp_sum;
                end
                
                // Move to next subarray
                if (r < N - 1) begin
                    r <= r + 1;
                end else if (l < N - 2) begin
                    l <= l + 1;
                    r <= l + 1;
                end
            end
            
            default: begin
                // No specific updates for other states
            end
        endcase
        
        // Safety timeout
        if (cycle_count >= MAX_CYCLES && state != FINISHED) begin
            state <= FINISHED;
        end
    end
end

assign max_sum = current_max;
assign done = (state == FINISHED);

endmodule