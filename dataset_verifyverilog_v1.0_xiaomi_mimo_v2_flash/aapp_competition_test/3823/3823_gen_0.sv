module jeff_rounding(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] data_in,
    input wire data_valid,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:1] READ_N        = 4'd1;
    localparam [3:1] READ_NUM      = 4'd2;
    localparam [3:1] EXTRACT_FRAC  = 4'd3;
    localparam [3:1] CHECK_COMPLETE = 4'd4;
    localparam [3:1] COMPUTE_LR    = 4'd5;
    localparam [3:1] COMPUTE_DIFF  = 4'd6;
    localparam [3:1] UPDATE_MIN    = 4'd7;
    localparam [3:1] INCREMENT_X   = 4'd8;
    localparam [3:1] OUTPUT_RESULT = 4'd9;

    // Internal registers
    reg [3:0] state, next_state;
    reg [31:0] n_reg;              // Total numbers to process (2n)
    reg [31:0] count_reg;          // Counter for processed numbers
    reg [31:0] m_reg;              // Count of non-integer numbers
    reg [31:0] T_reg;              // Sum of fractional parts
    reg [31:0] current_num;        // Current number being processed
    reg [31:0] L_reg;              // Lower bound for iteration
    reg [31:0] R_reg;              // Upper bound for iteration
    reg [31:0] x_reg;              // Current x value being tested
    reg [31:0] min_diff_reg;       // Minimum difference found
    reg [31:0] cycle_count;        // Prevent infinite loops
    localparam [31:0] MAX_CYCLES = 32'd200;

    // Temporary computation registers
    reg [31:0] diff_temp;
    reg [31:0] x_mult_1000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            n_reg <= 32'd0;
            count_reg <= 32'd0;
            m_reg <= 32'd0;
            T_reg <= 32'd0;
            current_num <= 32'd0;
            L_reg <= 32'd0;
            R_reg <= 32'd0;
            x_reg <= 32'd0;
            min_diff_reg <= 32'hFFFFFFFF;
            cycle_count <= 32'd0;
            diff_temp <= 32'd0;
            x_mult_1000 <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 32'd0;
                    if (start) begin
                        state <= READ_N;
                        count_reg <= 32'd0;
                        m_reg <= 32'd0;
                        T_reg <= 32'd0;
                        min_diff_reg <= 32'hFFFFFFFF;
                    end
                end

                READ_N: begin
                    if (data_valid) begin
                        n_reg <= data_in;
                        state <= READ_NUM;
                        count_reg <= 32'd0;
                    end
                end

                READ_NUM: begin
                    if (data_valid && count_reg < (n_reg << 1)) begin
                        current_num <= data_in;
                        state <= EXTRACT_FRAC;
                    end
                end

                EXTRACT_FRAC: begin
                    // Extract fractional part (data_in % 1000)
                    if (current_num[31:0] % 32'd1000 != 32'd0) begin
                        m_reg <= m_reg + 32'd1;
                        T_reg <= T_reg + (current_num % 32'd1000);
                    end
                    state <= CHECK_COMPLETE;
                end

                CHECK_COMPLETE: begin
                    count_reg <= count_reg + 32'd1;
                    if (count_reg + 32'd1 >= (n_reg << 1)) begin
                        state <= COMPUTE_LR;
                    end else begin
                        state <= READ_NUM;
                    end
                end

                COMPUTE_LR: begin
                    // L = max(0, m - n)
                    if (m_reg > n_reg) begin
                        L_reg <= m_reg - n_reg;
                    end else begin
                        L_reg <= 32'd0;
                    end
                    // R = min(m, n)
                    if (m_reg < n_reg) begin
                        R_reg <= m_reg;
                    end else begin
                        R_reg <= n_reg;
                    end
                    x_reg <= 32'd0;
                    state <= COMPUTE_DIFF;
                end

                COMPUTE_DIFF: begin
                    // x_mult_1000 = x_reg * 1000
                    x_mult_1000 <= x_reg * 32'd1000;
                    state <= UPDATE_MIN;
                end

                UPDATE_MIN: begin
                    // diff = |x*1000 - T|
                    if (x_mult_1000 >= T_reg) begin
                        diff_temp <= x_mult_1000 - T_reg;
                    end else begin
                        diff_temp <= T_reg - x_mult_1000;
                    end
                    state <= INCREMENT_X;
                end

                INCREMENT_X: begin
                    // Update minimum
                    if (diff_temp < min_diff_reg) begin
                        min_diff_reg <= diff_temp;
                    end
                    // Check if done
                    if (x_reg >= R_reg) begin
                        state <= OUTPUT_RESULT;
                    end else begin
                        x_reg <= x_reg + 32'd1;
                        state <= COMPUTE_DIFF;
                    end
                end

                OUTPUT_RESULT: begin
                    result <= min_diff_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule