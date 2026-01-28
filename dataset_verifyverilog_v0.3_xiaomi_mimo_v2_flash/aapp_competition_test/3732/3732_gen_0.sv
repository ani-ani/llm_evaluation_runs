module m_perfect_checker (
    input clk,
    input rst_n,
    input start,
    input signed [63:0] x_in,
    input signed [63:0] y_in,
    input signed [63:0] m_in,
    output reg signed [31:0] result,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CHECK     = 3'd1;
    localparam [2:0] NEGATIVE  = 3'd2;
    localparam [2:0] SIMULATE  = 3'd3;
    localparam [2:0] DONE      = 3'd4;
    
    // State and counter registers
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Data registers
    reg signed [63:0] x_reg;
    reg signed [63:0] y_reg;
    reg signed [63:0] m_reg;
    reg signed [31:0] op_count;
    
    // Intermediate computation registers
    reg signed [63:0] sum;
    reg signed [31:0] steps;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            cycle_count <= 8'd0;
            op_count <= 32'd0;
            x_reg <= 64'd0;
            y_reg <= 64'd0;
            m_reg <= 64'd0;
            sum <= 64'd0;
            steps <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    op_count <= 32'd0;
                    steps <= 32'd0;
                    if (start) begin
                        x_reg <= x_in;
                        y_reg <= y_in;
                        m_reg <= m_in;
                        state <= CHECK;
                    end
                end
                
                CHECK: begin
                    // Check if both are negative
                    if (x_reg <= 64'sd0 && y_reg <= 64'sd0) begin
                        result <= -32'sd1;
                        state <= DONE;
                    end
                    // Check if max >= m
                    else if ((x_reg >= y_reg && x_reg >= m_reg) || 
                             (y_reg > x_reg && y_reg >= m_reg)) begin
                        result <= 32'd0;
                        state <= DONE;
                    end
                    // Check for negative values
                    else if (x_reg < 64'sd0 || y_reg < 64'sd0) begin
                        state <= NEGATIVE;
                    end
                    else begin
                        state <= SIMULATE;
                    end
                end
                
                NEGATIVE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Make both non-negative by repeated addition
                    if (x_reg < 64'sd0 && y_reg < 64'sd0) begin
                        sum <= x_reg + y_reg;
                        steps <= steps + 32'sd1;
                        // Check after sum
                        if (sum >= 64'sd0) begin
                            x_reg <= sum;
                            y_reg <= 64'sd0;
                            state <= CHECK;
                        end else begin
                            x_reg <= sum;
                            y_reg <= 64'sd0;
                            // Continue in NEGATIVE if sum still negative
                            if (cycle_count >= MAX_CYCLES) begin
                                result <= -32'sd1;
                                state <= DONE;
                            end
                        end
                    end else if (x_reg < 64'sd0) begin
                        sum <= x_reg + y_reg;
                        steps <= steps + 32'sd1;
                        if (sum >= 64'sd0) begin
                            x_reg <= sum;
                            state <= CHECK;
                        end else begin
                            x_reg <= sum;
                            if (cycle_count >= MAX_CYCLES) begin
                                result <= -32'sd1;
                                state <= DONE;
                            end
                        end
                    end else begin // y_reg < 0
                        sum <= x_reg + y_reg;
                        steps <= steps + 32'sd1;
                        if (sum >= 64'sd0) begin
                            y_reg <= sum;
                            state <= CHECK;
                        end else begin
                            y_reg <= sum;
                            if (cycle_count >= MAX_CYCLES) begin
                                result <= -32'sd1;
                                state <= DONE;
                            end
                        end
                    end
                end
                
                SIMULATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Fibonacci growth: replace smaller with sum
                    if (x_reg <= y_reg) begin
                        sum <= x_reg + y_reg;
                        if (sum >= m_reg) begin
                            result <= steps + 32'sd1;
                            state <= DONE;
                        end else if (cycle_count >= MAX_CYCLES) begin
                            // Exceeded max cycles, return operations so far
                            result <= steps + 32'sd1;
                            state <= DONE;
                        end else begin
                            x_reg <= sum;
                            steps <= steps + 32'sd1;
                        end
                    end else begin
                        sum <= x_reg + y_reg;
                        if (sum >= m_reg) begin
                            result <= steps + 32'sd1;
                            state <= DONE;
                        end else if (cycle_count >= MAX_CYCLES) begin
                            result <= steps + 32'sd1;
                            state <= DONE;
                        end else begin
                            y_reg <= sum;
                            steps <= steps + 32'sd1;
                        end
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule