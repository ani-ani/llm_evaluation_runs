module AlternatingCostCalculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] c_in,
    input wire [15:0] r_in,
    input wire [7:0] s_in,
    output reg [23:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] index;
    reg [7:0] s_mem [0:15];
    reg [23:0] dp_pos, dp_neg, dp_empty;
    reg [23:0] next_dp_pos, next_dp_neg, next_dp_empty;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            done <= 1'b0;
            result <= 24'd0;
            cycle_count <= 8'd0;
            dp_pos <= 24'd0;
            dp_neg <= 24'd0;
            dp_empty <= 24'd0;
        end else begin
            state <= next_state;
            if (state == LOAD && index < 4'd16) begin
                s_mem[index] <= s_in;
                index <= index + 4'd1;
            end
            if (state == COMPUTE) begin
                dp_pos <= next_dp_pos;
                dp_neg <= next_dp_neg;
                dp_empty <= next_dp_empty;
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
                    index = 4'd0;
                end
            end
            LOAD: begin
                if (index == 4'd16) begin
                    next_state = COMPUTE;
                    index = 4'd0;
                    // Initialize DP states
                    dp_pos = 24'd0;
                    dp_neg = 24'd0;
                    dp_empty = 24'd0;
                end
            end
            COMPUTE: begin
                if (index == 4'd15) begin
                    next_state = FINISH;
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // DP computation
    always @(*) begin
        next_dp_pos = dp_pos;
        next_dp_neg = dp_neg;
        next_dp_empty = dp_empty;

        if (state == COMPUTE) begin
            // Current score
            wire signed [7:0] current = s_mem[index];
            wire [23:0] min_prev = (dp_pos < dp_neg) ? (dp_pos < dp_empty ? dp_pos : dp_empty) : (dp_neg < dp_empty ? dp_neg : dp_empty);

            // Cost to remove current element
            wire [23:0] cost_remove = min_prev + r_in;

            // Cost to keep as positive
            wire [23:0] cost_pos;
            if (current > 8'd0) begin
                wire [23:0] min_prev_neg_empty = (dp_neg < dp_empty) ? dp_neg : dp_empty;
                cost_pos = min_prev_neg_empty;
            end else begin
                wire [23:0] min_prev_neg_empty = (dp_neg < dp_empty) ? dp_neg : dp_empty;
                cost_pos = min_prev_neg_empty + c_in;
            end

            // Cost to keep as negative
            wire [23:0] cost_neg;
            if (current < 8'd0) begin
                wire [23:0] min_prev_pos_empty = (dp_pos < dp_empty) ? dp_pos : dp_empty;
                cost_neg = min_prev_pos_empty;
            end else begin
                wire [23:0] min_prev_pos_empty = (dp_pos < dp_empty) ? dp_pos : dp_empty;
                cost_neg = min_prev_pos_empty + c_in;
            end

            // Update DP states
            next_dp_pos = cost_pos;
            next_dp_neg = cost_neg;
            next_dp_empty = cost_remove;
        end
    end

    // Index increment
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            index <= 4'd0;
        end else begin
            if (state == COMPUTE && index < 4'd15) begin
                index <= index + 4'd1;
            end
        end
    end

    // Result and done
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            result <= 24'd0;
        end else begin
            if (state == FINISH) begin
                wire [23:0] final_min = (dp_pos < dp_neg) ? (dp_pos < dp_empty ? dp_pos : dp_empty) : (dp_neg < dp_empty ? dp_neg : dp_empty);
                result <= final_min;
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

    // Cycle counter for safety
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
        end else begin
            if (state != IDLE) begin
                cycle_count <= cycle_count + 8'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    state <= IDLE;
                    done <= 1'b1;
                    result <= 24'd0;
                end
            end
        end
    end

endmodule