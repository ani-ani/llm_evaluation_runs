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
reg [3:0] l;
reg [3:0] r;
reg [DATA_WIDTH-1:0] current_max;
reg [DATA_WIDTH-1:0] temp_sum;
reg [3:0] swap_count;
reg [3:0] inner_size;
reg [3:0] outer_size;
reg signed [DATA_WIDTH-1:0] inner_sorted [0:N-1];
reg signed [DATA_WIDTH-1:0] outer_sorted [0:N-1];
reg [3:0] sorted_idx;
integer i, j;

// Helper function for min
function [3:0] min;
    input [3:0] a, b;
    begin
        min = (a < b) ? a : b;
    end
endfunction

// Main state machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        l <= 4'd0;
        r <= 4'd0;
        current_max <= {DATA_WIDTH{1'b1}};
        temp_sum <= {DATA_WIDTH{1'b0}};
        swap_count <= 4'd0;
        inner_size <= 4'd0;
        outer_size <= 4'd0;
        done <= 1'b0;
        for (i = 0; i < N; i = i + 1) begin
            inner_sorted[i] <= {DATA_WIDTH{1'b0}};
            outer_sorted[i] <= {DATA_WIDTH{1'b0}};
        end
        sorted_idx <= 4'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    l <= 4'd0;
                    r <= 4'd0;
                    current_max <= {DATA_WIDTH{1'b1}};
                    state <= COMPUTE;
                    temp_sum <= {DATA_WIDTH{1'b0}};
                    swap_count <= 4'd0;
                    sorted_idx <= 4'd0;
                    for (i = 0; i < N; i = i + 1) begin
                        inner_sorted[i] <= {DATA_WIDTH{1'b0}};
                        outer_sorted[i] <= {DATA_WIDTH{1'b0}};
                    end
                end
            end
            
            COMPUTE: begin
                if (l == 4'd0 && r == 4'd0) begin
                    // Initialize subarray
                    temp_sum <= {DATA_WIDTH{1'b0}};
                    for (j = 0; j < N; j = j + 1) begin
                        if (j >= l && j <= r) begin
                            inner_sorted[j] <= a[j];
                            temp_sum <= temp_sum + a[j];
                        end else begin
                            outer_sorted[j] <= a[j];
                        end
                    end
                    inner_size <= (r - l) + 4'd1;
                    outer_size <= N - ((r - l) + 4'd1);
                    sorted_idx <= 4'd0;
                end
                
                // Inner array bubble sort (ascending)
                if (sorted_idx < inner_size - 4'd1) begin
                    if (inner_sorted[sorted_idx] > inner_sorted[sorted_idx + 1]) begin
                        inner_sorted[sorted_idx] <= inner_sorted[sorted_idx + 1];
                        inner_sorted[sorted_idx + 1] <= inner_sorted[sorted_idx];
                    end
                    sorted_idx <= sorted_idx + 4'd1;
                end
                
                state <= UPDATE;
            end
            
            UPDATE: begin
                if (swap_count < min(k, min(inner_size, outer_size))) begin
                    if (outer_sorted[swap_count] > inner_sorted[swap_count]) begin
                        temp_sum <= temp_sum + (outer_sorted[swap_count] - inner_sorted[swap_count]);
                    end
                    swap_count <= swap_count + 4'd1;
                    state <= COMPUTE;
                end else begin
                    if (temp_sum > current_max) begin
                        current_max <= temp_sum;
                    end
                    
                    // Move to next subarray
                    if (r < N - 4'd1) begin
                        r <= r + 4'd1;
                        state <= COMPUTE;
                    end else if (l < N - 4'd1) begin
                        l <= l + 4'd1;
                        r <= l;
                        state <= COMPUTE;
                    end else begin
                        state <= FINISHED;
                    end
                    
                    swap_count <= 4'd0;
                    temp_sum <= {DATA_WIDTH{1'b0}};
                end
            end
            
            FINISHED: begin
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule