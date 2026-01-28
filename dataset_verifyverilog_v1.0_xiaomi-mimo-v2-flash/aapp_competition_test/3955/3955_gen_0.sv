module max_bitwise_or (
    input clk,
    input rst_n,
    input start,
    input [31:0] arr [0:7],
    input [3:0] k,
    input [3:0] x,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] POW_CALC   = 3'd1;
    localparam [2:0] PREP_OR    = 3'd2;
    localparam [2:0] CANDIDATE  = 3'd3;
    localparam [2:0] UPDATE_MAX = 3'd4;
    localparam [2:0] FINISH     = 3'd5;

    reg [2:0] state, next_state;
    reg [31:0] x_power;
    reg [31:0] x_power_next;
    reg [31:0] max_candidate;
    reg [31:0] max_candidate_next;
    reg [2:0] i_idx;
    reg [2:0] i_idx_next;
    reg [31:0] left_or;
    reg [31:0] left_or_next;
    reg [31:0] right_or;
    reg [31:0] right_or_next;
    reg [31:0] candidate;
    reg [31:0] candidate_next;
    reg [31:0] temp_mult;
    reg [31:0] temp_mult_next;
    reg [31:0] result_reg;
    reg [31:0] result_reg_next;
    reg [3:0] pow_counter;
    reg [3:0] pow_counter_next;
    reg [2:0] or_idx;
    reg [2:0] or_idx_next;
    reg done_reg;
    reg done_reg_next;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            x_power <= 32'd0;
            max_candidate <= 32'd0;
            i_idx <= 3'd0;
            left_or <= 32'd0;
            right_or <= 32'd0;
            candidate <= 32'd0;
            temp_mult <= 32'd0;
            result_reg <= 32'd0;
            pow_counter <= 4'd0;
            or_idx <= 3'd0;
            done_reg <= 1'b0;
        end else begin
            state <= next_state;
            x_power <= x_power_next;
            max_candidate <= max_candidate_next;
            i_idx <= i_idx_next;
            left_or <= left_or_next;
            right_or <= right_or_next;
            candidate <= candidate_next;
            temp_mult <= temp_mult_next;
            result_reg <= result_reg_next;
            pow_counter <= pow_counter_next;
            or_idx <= or_idx_next;
            done_reg <= done_reg_next;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        x_power_next = x_power;
        max_candidate_next = max_candidate;
        i_idx_next = i_idx;
        left_or_next = left_or;
        right_or_next = right_or;
        candidate_next = candidate;
        temp_mult_next = temp_mult;
        result_reg_next = result_reg;
        pow_counter_next = pow_counter;
        or_idx_next = or_idx;
        done_reg_next = 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = POW_CALC;
                    x_power_next = 32'd1;
                    pow_counter_next = 4'd0;
                    max_candidate_next = 32'd0;
                    i_idx_next = 3'd0;
                    result_reg_next = 32'd0;
                end
            end

            POW_CALC: begin
                if (pow_counter < k) begin
                    x_power_next = x_power * {28'd0, x};
                    pow_counter_next = pow_counter + 4'd1;
                end else begin
                    next_state = PREP_OR;
                    or_idx_next = 3'd0;
                    left_or_next = 32'd0;
                    right_or_next = 32'd0;
                end
            end

            PREP_OR: begin
                if (i_idx < 4'd8) begin
                    // Compute left OR
                    if (or_idx < i_idx) begin
                        left_or_next = left_or | arr[or_idx];
                        or_idx_next = or_idx + 3'd1;
                        next_state = PREP_OR;
                    end else begin
                        // Compute right OR
                        if (or_idx < 3'd8) begin
                            if (or_idx > i_idx) begin
                                right_or_next = right_or | arr[or_idx];
                            end
                            or_idx_next = or_idx + 3'd1;
                            next_state = PREP_OR;
                        end else begin
                            next_state = CANDIDATE;
                        end
                    end
                end else begin
                    next_state = FINISH;
                end
            end

            CANDIDATE: begin
                // Multiply a[i] * x_power
                temp_mult_next = arr[i_idx] * x_power;
                // Compute candidate
                candidate_next = left_or | temp_mult | right_or;
                next_state = UPDATE_MAX;
            end

            UPDATE_MAX: begin
                if (candidate > max_candidate) begin
                    max_candidate_next = candidate;
                end
                i_idx_next = i_idx + 3'd1;
                if (i_idx < 3'd7) begin
                    next_state = PREP_OR;
                    or_idx_next = 3'd0;
                    left_or_next = 32'd0;
                    right_or_next = 32'd0;
                end else begin
                    next_state = FINISH;
                end
            end

            FINISH: begin
                result_reg_next = max_candidate;
                done_reg_next = 1'b1;
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Output assignments
    always @(*) begin
        result = result_reg;
        done = done_reg;
    end

endmodule