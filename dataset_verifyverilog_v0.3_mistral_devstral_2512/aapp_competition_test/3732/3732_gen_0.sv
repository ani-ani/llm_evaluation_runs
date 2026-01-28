module m_perfect_checker(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [63:0] x_in,
    input wire signed [63:0] y_in,
    input wire signed [63:0] m_in,
    output reg signed [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CHECK     = 3'd1;
    localparam [2:0] NEGATIVE  = 3'd2;
    localparam [2:0] SIMULATE  = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg signed [63:0] x_reg, y_reg, m_reg;
    reg signed [63:0] temp_x, temp_y;
    reg signed [31:0] op_count;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Signed comparison helper
    wire signed [63:0] max_val;
    assign max_val = (x_reg > y_reg) ? x_reg : y_reg;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK;
                end else begin
                    next_state = IDLE;
                end
            end

            CHECK: begin
                if (max_val >= m_reg) begin
                    next_state = DONE_STATE;
                end else if (x_reg <= 64'd0 && y_reg <= 64'd0) begin
                    next_state = DONE_STATE;
                end else if (x_reg < 64'd0 || y_reg < 64'd0) begin
                    next_state = NEGATIVE;
                end else begin
                    next_state = SIMULATE;
                end
            end

            NEGATIVE: begin
                if (x_reg >= 64'd0 && y_reg >= 64'd0) begin
                    next_state = SIMULATE;
                end else if (cycle_count >= MAX_CYCLES) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = NEGATIVE;
                end
            end

            SIMULATE: begin
                if (max_val >= m_reg || cycle_count >= MAX_CYCLES) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = SIMULATE;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // State register and main logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            x_reg <= 64'd0;
            y_reg <= 64'd0;
            m_reg <= 64'd0;
            temp_x <= 64'd0;
            temp_y <= 64'd0;
            op_count <= 32'd0;
            cycle_count <= 8'd0;
            result <= 32'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 32'd0;
                    if (start) begin
                        x_reg <= x_in;
                        y_reg <= y_in;
                        m_reg <= m_in;
                        op_count <= 32'd0;
                        cycle_count <= 8'd0;
                    end
                end

                CHECK: begin
                    done <= 1'b0;
                    if (max_val >= m_reg) begin
                        result <= 32'd0;
                    end else if (x_reg <= 64'd0 && y_reg <= 64'd0) begin
                        result <= 32'd-1;
                    end
                end

                NEGATIVE: begin
                    done <= 1'b0;
                    if (x_reg < 64'd0) begin
                        temp_x <= x_reg + y_reg;
                        temp_y <= y_reg;
                        x_reg <= temp_x;
                        op_count <= op_count + 32'd1;
                    end else if (y_reg < 64'd0) begin
                        temp_y <= x_reg + y_reg;
                        temp_x <= x_reg;
                        y_reg <= temp_y;
                        op_count <= op_count + 32'd1;
                    end
                    cycle_count <= cycle_count + 8'd1;
                end

                SIMULATE: begin
                    done <= 1'b0;
                    if (x_reg < y_reg) begin
                        temp_x <= x_reg + y_reg;
                        temp_y <= y_reg;
                    end else begin
                        temp_y <= x_reg + y_reg;
                        temp_x <= x_reg;
                    end
                    x_reg <= temp_x;
                    y_reg <= temp_y;
                    op_count <= op_count + 32'd1;
                    cycle_count <= cycle_count + 8'd1;

                    if (max_val >= m_reg) begin
                        result <= op_count;
                    end else if (cycle_count >= MAX_CYCLES) begin
                        result <= 32'd-1;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule