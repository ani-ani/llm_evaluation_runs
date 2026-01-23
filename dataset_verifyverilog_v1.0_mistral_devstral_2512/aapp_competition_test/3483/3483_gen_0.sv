module Figurine4Pack #(
    parameter N = 8,
    parameter WEIGHT_WIDTH = 8,
    parameter RESULT_WIDTH = 16,
    parameter FP_FRAC_BITS = 16
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [WEIGHT_WIDTH-1:0] weights [0:N-1],
    
    output reg [RESULT_WIDTH-1:0] max_weight,
    output reg [RESULT_WIDTH-1:0] min_weight,
    output reg [RESULT_WIDTH-1:0] num_distinct,
    output reg [31:0] expected_weight,
    output reg done
);

// State definitions
localparam [2:0] IDLE = 3'd0;
localparam [2:0] LOAD = 3'd1;
localparam [2:0] COMPUTE = 3'd2;
localparam [2:0] COUNT_DISTINCT = 3'd3;
localparam [2:0] DONE_STATE = 3'd4;

reg [2:0] state, next_state;

// Data storage
reg [WEIGHT_WIDTH-1:0] w [0:N-1];
reg [RESULT_WIDTH-1:0] sum_all;
reg [WEIGHT_WIDTH:0] min_val;
reg [WEIGHT_WIDTH:0] max_val;
reg [10:0] combo_idx;
reg [10:0] distinct_count;
reg [1020:0] seen_sums;

// Combinational signals
wire [2:0] i0 = combo_idx % N;
wire [2:0] i1 = (combo_idx / N) % N;
wire [2:0] i2 = (combo_idx / (N*N)) % N;
wire [2:0] i3 = (combo_idx / (N*N*N)) % N;
wire [WEIGHT_WIDTH:0] current_sum = w[i0] + w[i1] + w[i2] + w[i3];
wire [10:0] total_combos = N * N * N * N;

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        next_state <= IDLE;
    end else begin
        state <= next_state;
    end
end

always @(*) begin
    case (state)
        IDLE: next_state = start ? LOAD : IDLE;
        LOAD: next_state = COMPUTE;
        COMPUTE: next_state = COUNT_DISTINCT;
        COUNT_DISTINCT: next_state = (combo_idx >= total_combos) ? DONE_STATE : COUNT_DISTINCT;
        DONE_STATE: next_state = IDLE;
        default: next_state = IDLE;
    endcase
end

// Datapath
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        max_weight <= 16'd0;
        min_weight <= 16'd0;
        num_distinct <= 16'd0;
        expected_weight <= 32'd0;
        done <= 1'b0;
        sum_all <= 16'd0;
        min_val <= {1'b1, {WEIGHT_WIDTH{1'b1}}};
        max_val <= {1'b0, {WEIGHT_WIDTH{1'b0}}};
        combo_idx <= 11'd0;
        distinct_count <= 11'd0;
        seen_sums <= 1021'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    combo_idx <= 11'd0;
                    distinct_count <= 11'd0;
                    seen_sums <= 1021'd0;
                    min_val <= {1'b1, {WEIGHT_WIDTH{1'b1}}};
                    max_val <= {1'b0, {WEIGHT_WIDTH{1'b0}}};
                    sum_all <= 16'd0;
                end
            end
            
            LOAD: begin
                integer i;
                for (i = 0; i < N; i = i + 1) begin
                    w[i] <= weights[i];
                end
            end
            
            COMPUTE: begin
                integer i;
                for (i = 0; i < N; i = i + 1) begin
                    sum_all <= sum_all + w[i];
                    if (w[i] < min_val) min_val <= w[i];
                    if (w[i] > max_val) max_val <= w[i];
                end
            end
            
            COUNT_DISTINCT: begin
                if (!seen_sums[current_sum]) begin
                    seen_sums[current_sum] <= 1'b1;
                    distinct_count <= distinct_count + 1'b1;
                end
                combo_idx <= combo_idx + 1'b1;
            end
            
            DONE_STATE: begin
                max_weight <= max_val * 4;
                min_weight <= min_val * 4;
                num_distinct <= distinct_count;
                expected_weight <= (sum_all * 4 * (1 << FP_FRAC_BITS)) / N;
                done <= 1'b1;
            end
        endcase
    end
end

endmodule