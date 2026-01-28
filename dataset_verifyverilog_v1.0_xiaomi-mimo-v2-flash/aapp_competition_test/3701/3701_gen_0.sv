module MinimumCostToOnes (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] string,
    input wire [15:0] x_cost,
    input wire [15:0] y_cost,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] COUNT    = 3'd1;
    localparam [2:0] CHECK    = 3'd2;
    localparam [2:0] MIN_CALC = 3'd3;
    localparam [2:0] MULT     = 3'd4;
    localparam [2:0] FINISH   = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] bit_idx;              // Index for scanning 16 bits (0-15)
    reg [2:0] zero_groups;          // Max 8 groups
    reg [15:0] x_reg, y_reg;        // Store costs
    reg [15:0] min_val;             // min(x_cost, y_cost)
    reg [15:0] mult_operand;        // (groups - 1)
    reg [15:0] product;             // Multiplication result
    reg [3:0] mult_step;            // Step counter for sequential multiply
    
    // Helper for previous bit
    wire prev_bit;
    assign prev_bit = (bit_idx == 4'd0) ? 1'b0 : string[bit_idx - 4'd1];

    // Next state logic
    always @(*) begin
        case (state)
            IDLE:    next_state = start ? COUNT : IDLE;
            COUNT:   next_state = (bit_idx == 4'd15) ? CHECK : COUNT;
            CHECK:   next_state = (zero_groups == 3'd0) ? FINISH : MIN_CALC;
            MIN_CALC: next_state = MULT;
            MULT:    next_state = (mult_step == 4'd15) ? FINISH : MULT; // 16 cycles max
            FINISH:  next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // State transition and register updates
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            bit_idx <= 4'd0;
            zero_groups <= 3'd0;
            x_reg <= 16'd0;
            y_reg <= 16'd0;
            min_val <= 16'd0;
            mult_operand <= 16'd0;
            product <= 16'd0;
            mult_step <= 4'd0;
        end else begin
            state <= next_state;
            
            // Default assignments
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    bit_idx <= 4'd0;
                    zero_groups <= 3'd0;
                    if (start) begin
                        x_reg <= x_cost;
                        y_reg <= y_cost;
                    end
                end

                COUNT: begin
                    // Check for start of a zero group:
                    // 1. Current bit is 0
                    // 2. Either it's the first bit (bit_idx==0) OR previous bit was 1
                    if (string[bit_idx] == 1'b0 && (bit_idx == 4'd0 || prev_bit == 1'b1)) begin
                        zero_groups <= zero_groups + 3'd1;
                    end
                    bit_idx <= bit_idx + 4'd1;
                end

                CHECK: begin
                    // Nothing to do, just transition
                end

                MIN_CALC: begin
                    // Calculate min(x_cost, y_cost)
                    if (x_reg < y_reg)
                        min_val <= x_reg;
                    else
                        min_val <= y_reg;
                    
                    // Prepare for multiplication: (groups - 1) * min_val
                    mult_operand <= {13'd0, zero_groups - 3'd1}; // Zero-extend to 16 bits
                    product <= 16'd0;
                    mult_step <= 4'd0;
                end

                MULT: begin
                    // Simple 16x16 multiplication (Booth or shift-add)
                    // Since multiplier (groups-1) is small (0-7), we can just add min_val repeatedly
                    if (mult_operand > 16'd0) begin
                        product <= product + min_val;
                        mult_operand <= mult_operand - 16'd1;
                    end
                    mult_step <= mult_step + 4'd1;
                end

                FINISH: begin
                    if (zero_groups == 3'd0) begin
                        result <= 16'd0;
                    end else begin
                        // result = product + y_cost
                        result <= product + y_reg;
                    end
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule