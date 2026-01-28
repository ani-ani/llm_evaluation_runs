module RatioOfPositives (
    input clk,
    input rst_n,
    input start,
    input signed [7:0] arr [0:15],
    input [3:0] len,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] COUNTING  = 2'd1;
    localparam [1:0] DIVIDING  = 2'd2;
    localparam [1:0] FINISH    = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg [3:0] index;           // Array index counter (0 to 15)
    reg [3:0] pos_count;       // Count of positive numbers
    reg [3:0] len_reg;         // Store len for division
    reg [7:0] numerator;       // numerator = pos_count << 8
    reg [7:0] quotient;        // Division result
    reg [3:0] divisor;         // Division divisor
    reg [3:0] div_step;        // Division step counter
    reg div_busy;              // Division in progress flag
    
    // Combinatorial signals for positive detection
    wire is_positive;
    assign is_positive = (arr[index][7] == 1'b0) && (arr[index][6:0] != 7'd0);

    // Combinatorial division logic (shift-subtract algorithm)
    reg [7:0] div_remainder;
    reg [7:0] div_numer;
    reg [3:0] div_divisor;
    reg [3:0] div_counter;
    reg div_active;
    
    always @(*) begin
        // Default values
        div_remainder = quotient;
        div_numer = numerator;
        div_divisor = divisor;
        div_counter = div_step;
        div_active = div_busy;
        
        if (div_active && div_counter < 4'd9) begin
            // Shift left
            div_numer = {div_remainder[6:0], div_numer[7]};
            
            // Subtract if possible
            if (div_numer >= {4'd0, div_divisor}) begin
                div_remainder = {div_numer[6:0], 1'b1};
                div_numer = div_numer - {4'd0, div_divisor};
            end else begin
                div_remainder = {div_numer[6:0], 1'b0};
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            index <= 4'd0;
            pos_count <= 4'd0;
            len_reg <= 4'd0;
            numerator <= 8'd0;
            quotient <= 8'd0;
            divisor <= 4'd0;
            div_step <= 4'd0;
            div_busy <= 1'b0;
        end else begin
            done <= 1'b0;  // done is single cycle pulse
            
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= COUNTING;
                        index <= 4'd0;
                        pos_count <= 4'd0;
                        len_reg <= len;
                        // Handle len=0 edge case
                        if (len == 4'd0) begin
                            result <= 16'd0;
                            done <= 1'b1;
                            state <= IDLE;
                        end
                    end
                end
                
                COUNTING: begin
                    // Count positive numbers
                    if (is_positive) begin
                        pos_count <= pos_count + 4'd1;
                    end
                    
                    // Move to next element
                    if (index < len_reg - 4'd1) begin
                        index <= index + 4'd1;
                    end else begin
                        // Finished counting
                        state <= DIVIDING;
                        // Prepare for division: numerator = pos_count << 8
                        numerator <= {pos_count, 4'd0, 4'd0};  // pos_count * 256
                        divisor <= len_reg;
                        quotient <= 8'd0;
                        div_step <= 4'd0;
                        div_busy <= 1'b1;
                    end
                end
                
                DIVIDING: begin
                    if (div_busy && div_step < 4'd9) begin
                        // Use combinational result
                        quotient <= div_remainder;
                        numerator <= div_numer;
                        divisor <= div_divisor;
                        div_step <= div_step + 4'd1;
                    end else begin
                        // Division complete
                        div_busy <= 1'b0;
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    // Final result in Q8.8 format
                    result <= {quotient, 8'd0};  // quotient is 8-bit, fractional part zero
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule