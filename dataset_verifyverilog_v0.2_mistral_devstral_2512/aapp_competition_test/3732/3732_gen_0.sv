module m_perfect_solver (
    input clk,
    input rst_n,
    input start,
    input [31:0] x_in,
    input [31:0] y_in,
    input [31:0] m_in,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        CHECK_INIT,
        NEGATIVE_FIX,
        COMPUTE_LOOP,
        DONE
    } state_t;

    state_t state, next_state;

    // Internal registers
    reg [31:0] x_reg, y_reg, m_reg;
    reg [31:0] op_count;
    reg [31:0] temp_x, temp_y;
    reg [31:0] abs_x, abs_y;
    reg [31:0] quotient, remainder;
    reg [31:0] i;
    reg [31:0] loop_count;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'hFFFFFFFF; // -1
            op_count <= 32'h00000000;
            x_reg <= 32'h00000000;
            y_reg <= 32'h00000000;
            m_reg <= 32'h00000000;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_INIT;
                end
            end
            CHECK_INIT: begin
                next_state = NEGATIVE_FIX;
            end
            NEGATIVE_FIX: begin
                next_state = COMPUTE_LOOP;
            end
            COMPUTE_LOOP: begin
                if (loop_count >= 50 || (y_reg[31] == 0 && y_reg >= m_reg) || (y_reg[31] == 1 && m_reg[31] == 1 && y_reg <= m_reg)) begin
                    next_state = DONE;
                end
            end
            DONE: begin
                if (start) begin
                    next_state = CHECK_INIT;
                end
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_reg <= 32'h00000000;
            y_reg <= 32'h00000000;
            m_reg <= 32'h00000000;
            op_count <= 32'h00000000;
            loop_count <= 32'h00000000;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        x_reg <= x_in;
                        y_reg <= y_in;
                        m_reg <= m_in;
                        op_count <= 32'h00000000;
                        loop_count <= 32'h00000000;
                    end
                end
                CHECK_INIT: begin
                    if ((x_reg[31] == 0 && x_reg >= m_reg) || (x_reg[31] == 1 && m_reg[31] == 1 && x_reg <= m_reg) ||
                        (y_reg[31] == 0 && y_reg >= m_reg) || (y_reg[31] == 1 && m_reg[31] == 1 && y_reg <= m_reg)) begin
                        result <= 32'h00000000;
                        done <= 1'b1;
                        next_state = DONE;
                    end else if ((x_reg[31] == 1 && y_reg[31] == 1) && (m_reg[31] == 0 || m_reg != 32'h00000000)) begin
                        result <= 32'hFFFFFFFF; // -1
                        done <= 1'b1;
                        next_state = DONE;
                    end
                end
                NEGATIVE_FIX: begin
                    if (x_reg[31] == 1 && y_reg[31] == 0) begin
                        abs_x = ~x_reg + 1;
                        quotient = 32'h00000000;
                        remainder = abs_x;
                        for (i = 0; i < 32; i = i + 1) begin
                            remainder = remainder << 1;
                            if (remainder >= y_reg) begin
                                remainder = remainder - y_reg;
                                quotient[i] = 1'b1;
                            end
                        end
                        if (remainder != 32'h00000000) begin
                            quotient = quotient + 1;
                        end
                        op_count = op_count + quotient;
                        x_reg = y_reg * quotient - abs_x;
                    end else if (y_reg[31] == 1 && x_reg[31] == 0) begin
                        abs_y = ~y_reg + 1;
                        quotient = 32'h00000000;
                        remainder = abs_y;
                        for (i = 0; i < 32; i = i + 1) begin
                            remainder = remainder << 1;
                            if (remainder >= x_reg) begin
                                remainder = remainder - x_reg;
                                quotient[i] = 1'b1;
                            end
                        end
                        if (remainder != 32'h00000000) begin
                            quotient = quotient + 1;
                        end
                        op_count = op_count + quotient;
                        y_reg = x_reg * quotient - abs_y;
                    end
                end
                COMPUTE_LOOP: begin
                    if (x_reg > y_reg) begin
                        temp_x = x_reg;
                        x_reg = y_reg;
                        y_reg = temp_x;
                    end
                    if ((y_reg[31] == 0 && y_reg >= m_reg) || (y_reg[31] == 1 && m_reg[31] == 1 && y_reg <= m_reg)) begin
                        result <= op_count;
                        done <= 1'b1;
                        next_state = DONE;
                    end else if (y_reg[31] == 1 && m_reg[31] == 0) begin
                        result <= 32'hFFFFFFFF; // -1
                        done <= 1'b1;
                        next_state = DONE;
                    end else begin
                        temp_y = x_reg + y_reg;
                        x_reg = y_reg;
                        y_reg = temp_y;
                        op_count = op_count + 1;
                        loop_count = loop_count + 1;
                    end
                end
                DONE: begin
                    if (start) begin
                        done <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule