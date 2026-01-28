module FindSmallestX(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] m,
    input wire [3:0] n,
    input wire [7:0] p,
    input wire [7:0] q,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] INIT     = 3'd1;
    localparam [2:0] COMPUTE  = 3'd2;
    localparam [2:0] CHECK    = 3'd3;
    localparam [2:0] FOUND    = 3'd4;
    localparam [2:0] IMPOSSIBLE = 3'd5;
    localparam [2:0] FINISH   = 3'd6;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [15:0] candidate;
    reg [15:0] upper_limit;
    reg [15:0] lower_limit;
    reg [15:0] Y_reg;
    reg [15:0] term1;
    reg [31:0] product;
    reg [3:0] m_reg;
    reg [3:0] n_reg;
    reg [7:0] p_reg;
    reg [7:0] q_reg;
    reg [15:0] pow10_m_n;
    reg [15:0] pow10_n;
    reg [15:0] pow10_m;
    reg [7:0] pow10_calc_idx;
    reg [2:0] compute_stage;
    reg found_flag;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            candidate <= 16'd0;
            upper_limit <= 16'd0;
            lower_limit <= 16'd0;
            Y_reg <= 16'd0;
            term1 <= 16'd0;
            product <= 32'd0;
            m_reg <= 4'd0;
            n_reg <= 4'd0;
            p_reg <= 8'd0;
            q_reg <= 8'd0;
            pow10_m_n <= 16'd1;
            pow10_n <= 16'd1;
            pow10_m <= 16'd1;
            pow10_calc_idx <= 8'd0;
            compute_stage <= 3'd0;
            found_flag <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic and computations
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end

            INIT: begin
                // Store inputs and calculate powers of 10
                if (pow10_calc_idx < 8'd16) begin
                    // Calculate pow10_m and pow10_n and pow10_m_n
                    if (pow10_calc_idx < m_reg) begin
                        if (pow10_calc_idx < n_reg) begin
                            // pow10_n <= pow10_n * 10 (computed in sequential block)
                        end
                        // pow10_m <= pow10_m * 10 (computed in sequential block)
                    end
                    if (pow10_calc_idx < (m_reg - n_reg)) begin
                        // pow10_m_n <= pow10_m_n * 10 (computed in sequential block)
                    end
                    next_state = INIT;
                end else begin
                    lower_limit = pow10_m >> 1; // 10^(m-1)
                    upper_limit = pow10_m - 16'd1; // 10^m - 1
                    candidate = lower_limit;
                    next_state = COMPUTE;
                end
            end

            COMPUTE: begin
                if (candidate <= upper_limit) begin
                    next_state = CHECK;
                end else begin
                    next_state = IMPOSSIBLE;
                end
            end

            CHECK: begin
                // Y = candidate mod 10^(m-n)
                // term1 = Y * 10^n + p
                // product = q * term1
                if (compute_stage == 3'd0) begin
                    next_state = CHECK;
                end else if (compute_stage == 3'd1) begin
                    next_state = CHECK;
                end else if (compute_stage == 3'd2) begin
                    next_state = CHECK;
                end else begin
                    // Final check
                    if (product == candidate) begin
                        next_state = FOUND;
                    end else begin
                        candidate = candidate + 16'd1;
                        compute_stage = 3'd0;
                        next_state = COMPUTE;
                    end
                end
            end

            FOUND: begin
                next_state = FINISH;
            end

            IMPOSSIBLE: begin
                next_state = FINISH;
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Sequential logic for operations
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            candidate <= 16'd0;
            upper_limit <= 16'd0;
            lower_limit <= 16'd0;
            Y_reg <= 16'd0;
            term1 <= 16'd0;
            product <= 32'd0;
            m_reg <= 4'd0;
            n_reg <= 4'd0;
            p_reg <= 8'd0;
            q_reg <= 8'd0;
            pow10_m_n <= 16'd1;
            pow10_n <= 16'd1;
            pow10_m <= 16'd1;
            pow10_calc_idx <= 8'd0;
            compute_stage <= 3'd0;
            found_flag <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 16'd0;
                    if (start) begin
                        // Capture inputs
                        m_reg <= m;
                        n_reg <= n;
                        p_reg <= p;
                        q_reg <= q;
                        pow10_m_n <= 16'd1;
                        pow10_n <= 16'd1;
                        pow10_m <= 16'd1;
                        pow10_calc_idx <= 8'd0;
                    end
                end

                INIT: begin
                    // Calculate powers of 10
                    if (pow10_calc_idx < 8'd16) begin
                        // Update powers based on input ranges
                        // m <= 16, n <= 4
                        if (pow10_calc_idx < m_reg) begin
                            pow10_m <= pow10_m * 10;
                            if (pow10_calc_idx < n_reg) begin
                                pow10_n <= pow10_n * 10;
                            end
                        end
                        if (pow10_calc_idx < (m_reg - n_reg)) begin
                            pow10_m_n <= pow10_m_n * 10;
                        end
                        pow10_calc_idx <= pow10_calc_idx + 8'd1;
                    end
                end

                COMPUTE: begin
                    compute_stage <= 3'd0;
                    // Just transitions to CHECK
                end

                CHECK: begin
                    case (compute_stage)
                        3'd0: begin
                            // Y = candidate % pow10_m_n
                            if (pow10_m_n != 16'd0) begin
                                Y_reg <= candidate % pow10_m_n;
                            end else begin
                                Y_reg <= candidate;
                            end
                            compute_stage <= 3'd1;
                        end
                        3'd1: begin
                            // term1 = Y * pow10_n + p
                            term1 <= (Y_reg * pow10_n) + p_reg;
                            compute_stage <= 3'd2;
                        end
                        3'd2: begin
                            // product = q * term1
                            product <= q_reg * term1;
                            compute_stage <= 3'd3;
                        end
                        3'd3: begin
                            // Handled in next_state logic
                            compute_stage <= 3'd0;
                        end
                    endcase
                end

                FOUND: begin
                    result <= candidate;
                    done <= 1'b1;
                end

                IMPOSSIBLE: begin
                    result <= 16'd0;
                    done <= 1'b1;
                end

                FINISH: begin
                    // Wait for reset or next start
                end
            endcase
        end
    end

endmodule