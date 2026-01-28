module digit_product_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] B,
    input wire [7:0] N,
    output reg [31:0] X,
    output reg valid,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] SETUP       = 4'd1;
    localparam [3:0] FACTOR_LOOP = 4'd2;
    localparam [3:0] CHECK_N     = 4'd3;
    localparam [3:0] SORT_SETUP  = 4'd4;
    localparam [3:0] SORT_LOOP   = 4'd5;
    localparam [3:0] BUILD_X     = 4'd6;
    localparam [3:0] DONE        = 4'd7;
    localparam [3:0] IMPOSSIBLE  = 4'd8;

    // Registers
    reg [3:0] state, next_state;
    reg [7:0] temp_N;
    reg [3:0] d;
    reg [3:0] digits [0:7];
    reg [2:0] digit_count;
    reg [31:0] X_reg;
    reg [2:0] sort_i, sort_j;
    reg [2:0] build_idx;
    reg [7:0] start_N;
    reg [3:0] start_B;
    reg swap_detected;
    reg [2:0] cycle_count;
    localparam [2:0] MAX_CYCLES = 3'd6;

    integer i;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = SETUP;
                else
                    next_state = IDLE;
            end
            SETUP: begin
                next_state = FACTOR_LOOP;
            end
            FACTOR_LOOP: begin
                if (d < 3'd2)
                    next_state = CHECK_N;
                else if (temp_N % d == 8'd0)
                    next_state = FACTOR_LOOP;
                else
                    next_state = FACTOR_LOOP;
            end
            CHECK_N: begin
                if (temp_N == 8'd1)
                    next_state = SORT_SETUP;
                else
                    next_state = IMPOSSIBLE;
            end
            SORT_SETUP: begin
                if (digit_count > 3'd1)
                    next_state = SORT_LOOP;
                else if (digit_count == 3'd1)
                    next_state = BUILD_X;
                else
                    next_state = BUILD_X;
            end
            SORT_LOOP: begin
                if (cycle_count >= MAX_CYCLES)
                    next_state = BUILD_X;
                else if (!swap_detected && sort_j >= (digit_count - 3'd1))
                    next_state = BUILD_X;
                else
                    next_state = SORT_LOOP;
            end
            BUILD_X: begin
                if (build_idx >= digit_count)
                    next_state = DONE;
                else
                    next_state = BUILD_X;
            end
            DONE: next_state = IDLE;
            IMPOSSIBLE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            X <= 32'd0;
            valid <= 1'b0;
            done <= 1'b0;
            temp_N <= 8'd0;
            d <= 4'd0;
            digit_count <= 3'd0;
            X_reg <= 32'd0;
            sort_i <= 3'd0;
            sort_j <= 3'd0;
            build_idx <= 3'd0;
            start_N <= 8'd0;
            start_B <= 4'd0;
            swap_detected <= 1'b0;
            cycle_count <= 3'd0;
            for (i = 0; i < 8; i = i + 1) begin
                digits[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        start_N <= N;
                        start_B <= B;
                    end
                end
                SETUP: begin
                    temp_N <= start_N;
                    d <= (start_B - 4'd1);
                    digit_count <= 3'd0;
                    for (i = 0; i < 8; i = i + 1) begin
                        digits[i] <= 4'd0;
                    end
                end
                FACTOR_LOOP: begin
                    if (d >= 3'd2) begin
                        if (temp_N % d == 8'd0) begin
                            temp_N <= temp_N / d;
                            if (digit_count < 3'd8) begin
                                digits[digit_count] <= d;
                                digit_count <= digit_count + 3'd1;
                            end
                        end else begin
                            d <= d - 4'd1;
                        end
                    end
                end
                CHECK_N: begin
                    // No registers to update here
                end
                SORT_SETUP: begin
                    sort_i <= 3'd0;
                    sort_j <= 3'd0;
                    cycle_count <= 3'd0;
                    swap_detected <= 1'b0;
                end
                SORT_LOOP: begin
                    cycle_count <= cycle_count + 3'd1;
                    if (sort_j < (digit_count - 3'd1)) begin
                        if (digits[sort_j] > digits[sort_j + 3'd1]) begin
                            // Swap
                            digits[sort_j] <= digits[sort_j + 3'd1];
                            digits[sort_j + 3'd1] <= digits[sort_j];
                            swap_detected <= 1'b1;
                        end
                        sort_j <= sort_j + 3'd1;
                    end else begin
                        // End of pass
                        sort_i <= sort_i + 3'd1;
                        sort_j <= 3'd0;
                        swap_detected <= 1'b0;
                    end
                end
                BUILD_X: begin
                    if (build_idx == 3'd0) begin
                        X_reg <= 32'd0;
                    end else begin
                        X_reg <= X_reg * start_B;
                    end
                    if (build_idx < digit_count) begin
                        X_reg <= X_reg * start_B + digits[build_idx];
                    end
                    build_idx <= build_idx + 3'd1;
                    if (build_idx >= digit_count) begin
                        X <= X_reg;
                        valid <= 1'b1;
                    end
                end
                DONE: begin
                    done <= 1'b1;
                end
                IMPOSSIBLE: begin
                    X <= 32'd0;
                    valid <= 1'b0;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule