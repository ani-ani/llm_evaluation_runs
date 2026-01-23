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
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] SETUP = 4'd1;
    localparam [3:0] FACTOR_LOOP = 4'd2;
    localparam [3:0] CHECK_N = 4'd3;
    localparam [3:0] SORT_SETUP = 4'd4;
    localparam [3:0] SORT_LOOP = 4'd5;
    localparam [3:0] BUILD_X = 4'd6;
    localparam [3:0] DONE = 4'd7;
    localparam [3:0] IMPOSSIBLE = 4'd8;

    reg [3:0] state, next_state;

    // Datapath registers
    reg [7:0] temp_N;
    reg [3:0] d;
    reg [3:0] digits [0:7];
    reg [2:0] digit_count;
    reg [31:0] X_reg;
    reg [2:0] sort_i, sort_j;
    reg [2:0] build_idx;
    reg swap_flag;

    // Cycle counter to prevent infinite loops
    reg [6:0] cycle_count;
    localparam [6:0] MAX_CYCLES = 7'd100;

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
                if (N == 8'd1)
                    next_state = DONE;
                else
                    next_state = FACTOR_LOOP;
            end

            FACTOR_LOOP: begin
                if (d < 2 || temp_N == 8'd1)
                    next_state = CHECK_N;
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
                if (digit_count <= 1)
                    next_state = BUILD_X;
                else
                    next_state = SORT_LOOP;
            end

            SORT_LOOP: begin
                if (swap_flag || (sort_i == digit_count - 1 && sort_j == digit_count - 2))
                    next_state = SORT_SETUP;
                else
                    next_state = SORT_LOOP;
            end

            BUILD_X: begin
                if (build_idx == digit_count)
                    next_state = DONE;
                else
                    next_state = BUILD_X;
            end

            DONE: begin
                next_state = IDLE;
            end

            IMPOSSIBLE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            temp_N <= 8'd0;
            d <= 4'd0;
            digit_count <= 3'd0;
            X_reg <= 32'd0;
            sort_i <= 3'd0;
            sort_j <= 3'd0;
            build_idx <= 3'd0;
            swap_flag <= 1'b0;
            cycle_count <= 7'd0;
            valid <= 1'b0;
            done <= 1'b0;
            X <= 32'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 7'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 7'd0;
                end

                SETUP: begin
                    temp_N <= N;
                    d <= B - 4'd1;
                    digit_count <= 3'd0;
                    X_reg <= 32'd0;
                    build_idx <= 3'd0;
                end

                FACTOR_LOOP: begin
                    if (temp_N % d == 8'd0) begin
                        digits[digit_count] <= d;
                        digit_count <= digit_count + 3'd1;
                        temp_N <= temp_N / d;
                    end else begin
                        d <= d - 4'd1;
                    end
                end

                CHECK_N: begin
                    if (temp_N != 8'd1) begin
                        valid <= 1'b0;
                    end
                end

                SORT_SETUP: begin
                    sort_i <= 3'd0;
                    sort_j <= 3'd0;
                    swap_flag <= 1'b0;
                end

                SORT_LOOP: begin
                    if (digits[sort_j] > digits[sort_j + 1]) begin
                        reg [3:0] temp;
                        temp <= digits[sort_j];
                        digits[sort_j] <= digits[sort_j + 1];
                        digits[sort_j + 1] <= temp;
                        swap_flag <= 1'b1;
                    end

                    if (sort_j < digit_count - 2) begin
                        sort_j <= sort_j + 3'd1;
                    end else begin
                        sort_j <= 3'd0;
                        if (sort_i < digit_count - 2) begin
                            sort_i <= sort_i + 3'd1;
                        end
                    end
                end

                BUILD_X: begin
                    if (build_idx < digit_count) begin
                        X_reg <= X_reg * B + digits[build_idx];
                        build_idx <= build_idx + 3'd1;
                    end
                end

                DONE: begin
                    X <= X_reg;
                    valid <= 1'b1;
                    done <= 1'b1;
                end

                IMPOSSIBLE: begin
                    valid <= 1'b0;
                    done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Prevent infinite loops
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES && state != IDLE) begin
            state <= IDLE;
            done <= 1'b1;
            valid <= 1'b0;
            cycle_count <= 7'd0;
        end
    end

endmodule