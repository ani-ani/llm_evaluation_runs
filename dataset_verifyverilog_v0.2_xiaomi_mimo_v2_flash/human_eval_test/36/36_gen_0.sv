module fizz_buzz(
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg [7:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam CHECK = 3'b001;
    localparam DIV_CHECK = 3'b010;
    localparam COUNT_SEVENS = 3'b011;
    localparam ACCUMULATE = 3'b100;
    localparam INCREMENT = 3'b101;
    localparam DONE = 3'b110;

    reg [2:0] state;
    reg [7:0] i;
    reg [7:0] temp_count;
    reg divisible;
    reg [7:0] mod11;
    reg [7:0] mod13;
    reg [7:0] digit_units;
    reg [7:0] digit_tens;
    reg [7:0] digit_hundreds;
    reg [7:0] sevens_count;

    // Combinational logic for modulo operations
    always @(*) begin
        // Compute i % 11 using repeated subtraction (combinational)
        mod11 = i;
        if (i >= 8'd121) mod11 = i - 8'd110;
        if (mod11 >= 8'd11) mod11 = mod11 - 8'd11;
        if (mod11 >= 8'd11) mod11 = mod11 - 8'd11;
        if (mod11 >= 8'd11) mod11 = mod11 - 8'd11;
        if (mod11 >= 8'd11) mod11 = mod11 - 8'd11;
        if (mod11 >= 8'd11) mod11 = mod11 - 8'd11;
        if (mod11 >= 8'd11) mod11 = mod11 - 8'd11;
        if (mod11 >= 8'd11) mod11 = mod11 - 8'd11;
        if (mod11 >= 8'd11) mod11 = mod11 - 8'd11;
        if (mod11 >= 8'd11) mod11 = mod11 - 8'd11;
        if (mod11 >= 8'd11) mod11 = mod11 - 8'd11;
        if (mod11 >= 8'd11) mod11 = mod11 - 8'd11;
        if (mod11 >= 8'd11) mod11 = mod11 - 8'd11;
        if (mod11 >= 8'd11) mod11 = mod11 - 8'd11;
        if (mod11 >= 8'd11) mod11 = mod11 - 8'd11;
        if (mod11 >= 8'd11) mod11 = mod11 - 8'd11;
        if (mod11 >= 8'd11) mod11 = mod11 - 8'd11;
        if (mod11 >= 8'd11) mod11 = mod11 - 8'd11;
        if (mod11 >= 8'd11) mod11 = mod11 - 8'd11;
        if (mod11 >= 8'd11) mod11 = mod11 - 8'd11;
        if (mod11 >= 8'd11) mod11 = mod11 - 8'd11;
        if (mod11 >= 8'd11) mod11 = mod11 - 8'd11;
        if (mod11 >= 8'd11) mod11 = mod11 - 8'd11;
        if (mod11 >= 8'd11) mod11 = mod11 - 8'd11;
        // Now mod11 holds i % 11
        
        // Compute i % 13 using repeated subtraction
        mod13 = i;
        if (mod13 >= 8'd13) mod13 = mod13 - 8'd13;
        if (mod13 >= 8'd13) mod13 = mod13 - 8'd13;
        if (mod13 >= 8'd13) mod13 = mod13 - 8'd13;
        if (mod13 >= 8'd13) mod13 = mod13 - 8'd13;
        if (mod13 >= 8'd13) mod13 = mod13 - 8'd13;
        if (mod13 >= 8'd13) mod13 = mod13 - 8'd13;
        if (mod13 >= 8'd13) mod13 = mod13 - 8'd13;
        if (mod13 >= 8'd13) mod13 = mod13 - 8'd13;
        if (mod13 >= 8'd13) mod13 = mod13 - 8'd13;
        if (mod13 >= 8'd13) mod13 = mod13 - 8'd13;
        if (mod13 >= 8'd13) mod13 = mod13 - 8'd13;
        if (mod13 >= 8'd13) mod13 = mod13 - 8'd13;
        if (mod13 >= 8'd13) mod13 = mod13 - 8'd13;
        if (mod13 >= 8'd13) mod13 = mod13 - 8'd13;
        if (mod13 >= 8'd13) mod13 = mod13 - 8'd13;
        if (mod13 >= 8'd13) mod13 = mod13 - 8'd13;
        if (mod13 >= 8'd13) mod13 = mod13 - 8'd13;
        if (mod13 >= 8'd13) mod13 = mod13 - 8'd13;
        if (mod13 >= 8'd13) mod13 = mod13 - 8'd13;
        // Now mod13 holds i % 13
        
        divisible = (mod11 == 8'd0) || (mod13 == 8'd0);
        
        // Extract decimal digits
        digit_units = i % 10;
        digit_tens = (i / 10) % 10;
        digit_hundreds = i / 100;
        
        // Count 7s
        sevens_count = 0;
        if (digit_units == 4'd7) sevens_count = sevens_count + 1;
        if (digit_tens == 4'd7) sevens_count = sevens_count + 1;
        if (digit_hundreds == 4'd7) sevens_count = sevens_count + 1;
    end

    // State machine and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 8'd0;
            result <= 8'd0;
            done <= 1'b0;
            temp_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        if (n == 8'd0) begin
                            result <= 8'd0;
                            done <= 1'b1;
                            state <= IDLE;
                        end else begin
                            i <= 8'd0;
                            result <= 8'd0;
                            state <= CHECK;
                        end
                    end
                end
                
                CHECK: begin
                    if (i < n) begin
                        state <= DIV_CHECK;
                    end else begin
                        state <= DONE;
                        done <= 1'b1;
                    end
                end
                
                DIV_CHECK: begin
                    if (divisible) begin
                        state <= COUNT_SEVENS;
                    end else begin
                        state <= INCREMENT;
                    end
                end
                
                COUNT_SEVENS: begin
                    temp_count <= sevens_count;
                    state <= ACCUMULATE;
                end
                
                ACCUMULATE: begin
                    result <= result + temp_count;
                    state <= INCREMENT;
                end
                
                INCREMENT: begin
                    i <= i + 8'd1;
                    state <= CHECK;
                end
                
                DONE: begin
                    // Stay done, wait for reset or next start
                    if (!start) begin
                        state <= DONE;
                    end
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule