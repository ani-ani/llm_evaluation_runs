module bidirectional_counter(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr_0_a, arr_0_b,
    input [7:0] arr_1_a, arr_1_b,
    input [7:0] arr_2_a, arr_2_b,
    input [7:0] arr_3_a, arr_3_b,
    input [7:0] arr_4_a, arr_4_b,
    input [7:0] arr_5_a, arr_5_b,
    input [7:0] arr_6_a, arr_6_b,
    input [7:0] arr_7_a, arr_7_b,
    input [3:0] num_tuples,
    output reg [15:0] result,
    output reg done
);

    parameter DATA_WIDTH = 8;
    parameter MAX_TUPLES = 7;

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] OUTER_LOOP = 3'd2;
    localparam [2:0] INNER_LOOP = 3'd3;
    localparam [2:0] COMPARE = 3'd4;
    localparam [2:0] INCREMENT = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    // Registers
    reg [2:0] state, next_state;
    reg [7:0] tuple [0:7];
    reg [2:0] outer_idx, inner_idx;
    reg [15:0] count;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd30;

    // Load input tuples into registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            count <= 16'd0;
            outer_idx <= 3'd0;
            inner_idx <= 3'd0;
            cycle_count <= 8'd0;
            tuple[0] <= {arr_0_a, arr_0_b};
            tuple[1] <= {arr_1_a, arr_1_b};
            tuple[2] <= {arr_2_a, arr_2_b};
            tuple[3] <= {arr_3_a, arr_3_b};
            tuple[4] <= {arr_4_a, arr_4_b};
            tuple[5] <= {arr_5_a, arr_5_b};
            tuple[6] <= {arr_6_a, arr_6_b};
            tuple[7] <= {arr_7_a, arr_7_b};
        end else begin
            state <= next_state;
            done <= 1'b0;
            result <= count;
            if (state == LOAD) begin
                tuple[0] <= {arr_0_a, arr_0_b};
                tuple[1] <= {arr_1_a, arr_1_b};
                tuple[2] <= {arr_2_a, arr_2_b};
                tuple[3] <= {arr_3_a, arr_3_b};
                tuple[4] <= {arr_4_a, arr_4_b};
                tuple[5] <= {arr_5_a, arr_5_b};
                tuple[6] <= {arr_6_a, arr_6_b};
                tuple[7] <= {arr_7_a, arr_7_b};
            end
            if (state == INCREMENT) begin
                count <= count + 16'd1;
            end
            if (state == OUTER_LOOP) begin
                outer_idx <= outer_idx + 3'd1;
            end
            if (state == INNER_LOOP) begin
                inner_idx <= inner_idx + 3'd1;
            end
            if (state == DONE_STATE) begin
                done <= 1'b1;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end
            LOAD: begin
                if (num_tuples < 2) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = OUTER_LOOP;
                    outer_idx = 3'd0;
                    inner_idx = 3'd1;
                end
            end
            OUTER_LOOP: begin
                if (outer_idx >= num_tuples - 1) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = INNER_LOOP;
                    inner_idx = outer_idx + 3'd1;
                end
            end
            INNER_LOOP: begin
                if (inner_idx >= num_tuples) begin
                    next_state = OUTER_LOOP;
                end else begin
                    next_state = COMPARE;
                end
            end
            COMPARE: begin
                if (tuple[outer_idx][7:0] == tuple[inner_idx][15:8] && 
                    tuple[outer_idx][15:8] == tuple[inner_idx][7:0]) begin
                    next_state = INCREMENT;
                end else begin
                    next_state = INNER_LOOP;
                    inner_idx = inner_idx + 3'd1;
                end
            end
            INCREMENT: begin
                next_state = INNER_LOOP;
                inner_idx = inner_idx + 3'd1;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule