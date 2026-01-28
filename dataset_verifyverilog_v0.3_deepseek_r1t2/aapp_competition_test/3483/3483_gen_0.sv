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
    localparam [2:0] IDLE           = 3'd0;
    localparam [2:0] LOAD_WEIGHTS   = 3'd1;
    localparam [2:0] COMPUTE_STATS  = 3'd2;
    localparam [2:0] COUNT_SUMS     = 3'd3;
    localparam [2:0] FINISH         = 3'd4;

    reg [2:0] state, next_state;

    // Data storage
    reg [WEIGHT_WIDTH-1:0] w [0:N-1];
    reg [RESULT_WIDTH-1:0] sum_all;
    reg [WEIGHT_WIDTH-1:0] min_val;
    reg [WEIGHT_WIDTH-1:0] max_val;
    reg [15:0] combo_idx;
    reg [15:0] distinct_count;
    reg [1023:0] seen_sums;  // Covers all possible 10-bit sums (4 * 255 = 1020)
    wire [10:0] current_sum;

    // Combination indices
    wire [2:0] i0;
    wire [2:0] i1;
    wire [2:0] i2;
    wire [2:0] i3;
    wire [15:0] total_combos = N * N * N * N;

    // Combinational calculations
    assign i0 = combo_idx % N;
    assign i1 = (combo_idx / N) % N;
    assign i2 = (combo_idx / (N * N)) % N;
    assign i3 = (combo_idx / (N * N * N)) % N;
    assign current_sum = w[i0] + w[i1] + w[i2] + w[i3];

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else state <= next_state;
    end

    always @(*) begin
        next_state = IDLE;
        case (state)
            IDLE:          next_state = start ? LOAD_WEIGHTS : IDLE;
            LOAD_WEIGHTS:  next_state = COMPUTE_STATS;
            COMPUTE_STATS: next_state = COUNT_SUMS;
            COUNT_SUMS:    next_state = (combo_idx == total_combos - 1) ? FINISH : COUNT_SUMS;
            FINISH:        next_state = IDLE;
            default:       next_state = IDLE;
        endcase
    end

    // Datapath
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            state <= IDLE;
            sum_all <= {RESULT_WIDTH{1'b0}};
            max_weight <= {RESULT_WIDTH{1'b0}};
            min_weight <= {RESULT_WIDTH{1'b0}};
            num_distinct <= {RESULT_WIDTH{1'b0}};
            expected_weight <= 32'd0;
            combo_idx <= 16'd0;
            distinct_count <= 16'd0;
            seen_sums <= 1024'd0;
            
            // Initialize weights array
            for (i = 0; i < N; i = i + 1) begin
                w[i] <= {WEIGHT_WIDTH{1'b0}};
            end
            
            // Initialize min/max
            min_val <= {WEIGHT_WIDTH{1'b1}};
            max_val <= {WEIGHT_WIDTH{1'b0}};
        end
        else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        combo_idx <= 16'd0;
                        distinct_count <= 16'd0;
                        seen_sums <= 1024'd0;
                        sum_all <= {RESULT_WIDTH{1'b0}};
                        min_val <= {WEIGHT_WIDTH{1'b1}};
                        max_val <= {WEIGHT_WIDTH{1'b0}};
                    end
                end
                
                LOAD_WEIGHTS: begin
                    for (i = 0; i < N; i = i + 1) begin
                        w[i] <= weights[i];
                    end
                end
                
                COMPUTE_STATS: begin
                    sum_all <= {RESULT_WIDTH{1'b0}};
                    for (i = 0; i < N; i = i + 1) begin
                        sum_all <= sum_all + w[i];
                        if (w[i] < min_val) min_val <= w[i];
                        if (w[i] > max_val) max_val <= w[i];
                    end
                end
                
                COUNT_SUMS: begin
                    if (!seen_sums[current_sum]) begin
                        seen_sums[current_sum] <= 1'b1;
                        distinct_count <= distinct_count + 16'd1;
                    end
                    combo_idx <= combo_idx + 16'd1;
                end
                
                FINISH: begin
                    max_weight <= max_val * 4'd4;
                    min_weight <= min_val * 4'd4;
                    num_distinct <= distinct_count;
                    expected_weight <= ($unsigned(sum_all) * 4'd4) * $unsigned((32'd1 << FP_FRAC_BITS)) / N;
                    done <= 1'b1;
                end
            endcase
        end
    end
endmodule