module k_gon_area_calculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] k,
    input wire signed [31:0] x [0:15],
    input wire signed [31:0] y [0:15],
    output reg signed [63:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CALC_AREA = 3'd1;
    localparam [2:0] DIVIDE    = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd250;

    // Area calculation registers
    reg [7:0] i_reg;
    reg signed [63:0] total_area;
    reg signed [63:0] temp_product1;
    reg signed [63:0] temp_product2;

    // Division registers
    reg [63:0] dividend;
    reg [7:0] divisor;
    reg [63:0] quotient;
    reg [7:0] div_counter;
    reg signed [63:0] remainder;

    // FSM state transitions
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            i_reg <= 8'd0;
            total_area <= 64'd0;
            dividend <= 64'd0;
            divisor <= 8'd0;
            quotient <= 64'd0;
            div_counter <= 8'd0;
            remainder <= 64'd0;
            result <= 64'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= CALC_AREA;
                        i_reg <= 8'd0;
                        total_area <= 64'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CALC_AREA: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Calculate triangle area for current i
                    // temp_product1 = (x[i] - x[0]) * (y[i+1] - y[0])
                    temp_product1 <= ($signed(x[i_reg]) - $signed(x[0])) * 
                                    ($signed(y[i_reg + 1]) - $signed(y[0]));
                    
                    // temp_product2 = (y[i] - y[0]) * (x[i+1] - x[0])
                    temp_product2 <= ($signed(y[i_reg]) - $signed(y[0])) * 
                                    ($signed(x[i_reg + 1]) - $signed(x[0]));
                    
                    // Accumulate the difference
                    total_area <= total_area + (temp_product1 - temp_product2);
                    
                    // Move to next vertex
                    i_reg <= i_reg + 8'd1;
                    
                    // Check if done with area calculation
                    if (i_reg == n - 4'd1) begin
                        next_state <= DIVIDE;
                        // Prepare for division: (total_area * k) / n
                        dividend <= total_area * $signed(k);
                        divisor <= n;
                        quotient <= 64'd0;
                        remainder <= 64'd0;
                        div_counter <= 8'd0;
                    end else begin
                        next_state <= CALC_AREA;
                    end
                end

                DIVIDE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Restoring division algorithm
                    if (div_counter == 8'd0) begin
                        remainder <= dividend;
                    end
                    
                    // Shift left
                    remainder <= remainder << 1;
                    quotient <= quotient << 1;
                    
                    // Subtract divisor if remainder is positive
                    if (remainder[63] == 1'b0) begin
                        remainder <= remainder - {56'd0, divisor};
                        quotient[0] <= 1'b1;
                    end else begin
                        quotient[0] <= 1'b0;
                    end
                    
                    div_counter <= div_counter + 8'd1;
                    
                    // Check if division complete
                    if (div_counter == 8'd64) begin
                        next_state <= DONE_STATE;
                        result <= quotient;
                    end else begin
                        next_state <= DIVIDE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule