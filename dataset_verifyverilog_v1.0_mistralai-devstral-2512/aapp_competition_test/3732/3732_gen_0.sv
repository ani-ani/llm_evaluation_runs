module m_perfect_finder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [15:0] x_in,
    input wire signed [15:0] y_in,
    input wire signed [15:0] m_in,
    output reg signed [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg signed [15:0] x_reg, y_reg, m_reg;
    reg signed [31:0] op_count;
    reg signed [31:0] safety_counter;
    localparam [31:0] MAX_SAFETY = 32'd1024;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            op_count <= 32'd0;
            safety_counter <= 32'd0;
            x_reg <= 16'd0;
            y_reg <= 16'd0;
            m_reg <= 16'd0;
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
                    next_state = COMPUTE;
                end
            end
            COMPUTE: begin
                if (safety_counter >= MAX_SAFETY) begin
                    next_state = FINISH;
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Data processing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_reg <= 16'd0;
            y_reg <= 16'd0;
            m_reg <= 16'd0;
            op_count <= 32'd0;
            safety_counter <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        x_reg <= x_in;
                        y_reg <= y_in;
                        m_reg <= m_in;
                        op_count <= 32'd0;
                        safety_counter <= 32'd0;
                    end
                end
                COMPUTE: begin
                    safety_counter <= safety_counter + 32'd1;
                    
                    // Check if already m-perfect
                    if (x_reg >= m_reg || y_reg >= m_reg) begin
                        op_count <= 32'd0;
                        next_state = FINISH;
                    
                    // Check impossible case
                    else if (y_reg <= 16'd0) begin
                        op_count <= 32'd-1;
                        next_state = FINISH;
                    
                    // Handle negative x
                    else if (x_reg < 16'd0) begin
                        reg signed [31:0] steps;
                        steps = (32'd0 - x_reg + y_reg - 32'd1) / y_reg;
                        x_reg <= x_reg + steps * y_reg;
                        op_count <= op_count + steps;
                    
                    // Fibonacci step
                    else if (y_reg < m_reg) begin
                        reg signed [31:0] temp;
                        temp = x_reg + y_reg;
                        x_reg <= y_reg;
                        y_reg <= temp[15:0];
                        op_count <= op_count + 32'd1;
                    
                    // Finished
                    else begin
                        next_state = FINISH;
                    end
                end
                FINISH: begin
                    result <= op_count;
                    done <= 1'b1;
                end
                default: begin
                    x_reg <= 16'd0;
                    y_reg <= 16'd0;
                    m_reg <= 16'd0;
                    op_count <= 32'd0;
                    safety_counter <= 32'd0;
                end
            endcase
        end
    end

    // Done signal handling
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else begin
            if (state == FINISH) begin
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule