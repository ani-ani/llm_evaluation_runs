module move_one_ball(
    input clk,
    input rst_n,
    input start,
    input [7:0][7:0] arr,
    output reg result,
    output reg done
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam CHECK_SORTED = 3'b001;
    localparam COUNT_DROPS = 3'b010;
    localparam VALIDATE = 3'b011;
    localparam DONE = 3'b100;

    // Registers
    reg [2:0] state, next_state;
    reg [2:0] idx;  // Counter for array index (0-7)
    reg [2:0] idx_next;
    reg is_sorted_reg, is_sorted_next;
    reg [2:0] drop_count, drop_count_next;
    reg result_reg, result_next;
    reg done_reg, done_next;

    // State transition logic
    always @(*) begin
        next_state = state;
        idx_next = idx;
        is_sorted_next = is_sorted_reg;
        drop_count_next = drop_count;
        result_next = result_reg;
        done_next = done_reg;

        case (state)
            IDLE: begin
                done_next = 1'b0;
                if (start) begin
                    next_state = CHECK_SORTED;
                    idx_next = 3'd0;
                    is_sorted_next = 1'b1;
                end
            end

            CHECK_SORTED: begin
                // Check arr[idx] <= arr[idx+1], with wrap-around for idx=7
                if (idx < 7) begin
                    if (arr[idx] > arr[idx + 1]) begin
                        is_sorted_next = 1'b0;
                    end
                end else begin  // idx == 7
                    if (arr[7] > arr[0]) begin
                        is_sorted_next = 1'b0;
                    end
                end

                if (idx < 7) begin
                    idx_next = idx + 1;
                end else begin
                    next_state = COUNT_DROPS;
                    idx_next = 3'd0;
                    drop_count_next = 3'd0;
                end
            end

            COUNT_DROPS: begin
                // Count drops: arr[idx] > arr[idx+1] (with wrap)
                if (idx < 7) begin
                    if (arr[idx] > arr[idx + 1]) begin
                        drop_count_next = drop_count + 1;
                    end
                end else begin  // idx == 7
                    if (arr[7] > arr[0]) begin
                        drop_count_next = drop_count + 1;
                    end
                end

                if (idx < 7) begin
                    idx_next = idx + 1;
                end else begin
                    next_state = VALIDATE;
                end
            end

            VALIDATE: begin
                // If already sorted, result = 1
                // Else if exactly 1 drop, result = 1
                // Otherwise, result = 0
                if (is_sorted_reg) begin
                    result_next = 1'b1;
                end else if (drop_count == 3'd1) begin
                    result_next = 1'b1;
                end else begin
                    result_next = 1'b0;
                end
                next_state = DONE;
            end

            DONE: begin
                // Hold result and done signal
                // Wait for start to go low before accepting new start
                if (!start) begin
                    next_state = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx <= 3'd0;
            is_sorted_reg <= 1'b0;
            drop_count <= 3'd0;
            result_reg <= 1'b0;
            done_reg <= 1'b0;
        end else begin
            state <= next_state;
            idx <= idx_next;
            is_sorted_reg <= is_sorted_next;
            drop_count <= drop_count_next;
            result_reg <= result_next;
            done_reg <= done_next;
        end
    end

    // Output assignments
    always @(*) begin
        result = result_reg;
        done = done_reg;
    end

endmodule