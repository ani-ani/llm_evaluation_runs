module digits_product (
    input clk,
    input rst_n,
    input start,
    input [23:0] n,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] PROCESS  = 3'd1;
    localparam [2:0] CHECK    = 3'd2;
    localparam [2:0] MULTIPLY = 3'd3;
    localparam [2:0] SUBTRACT = 3'd4;
    localparam [2:0] DONE     = 3'd5;

    // Internal registers
    reg [2:0] state;
    reg [23:0] temp_n;
    reg [3:0] digit;
    reg [15:0] stored_digit;
    reg any_odd;
    reg [23:0] sub_count;
    reg sub_active;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            temp_n <= 24'd0;
            digit <= 4'd0;
            stored_digit <= 16'd0;
            any_odd <= 1'b0;
            sub_count <= 24'd0;
            sub_active <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        temp_n <= n;
                        result <= 16'd1;
                        any_odd <= 1'b0;
                        state <= PROCESS;
                    end
                end

                PROCESS: begin
                    if (temp_n > 24'd0) begin
                        // Extract digit: digit = temp_n % 10
                        // Using subtraction method for modulo 10
                        if (temp_n >= 24'd10) begin
                            // Need to subtract 10 repeatedly
                            sub_count <= 24'd0;
                            sub_active <= 1'b1;
                            state <= SUBTRACT;
                        end else begin
                            digit <= temp_n[3:0];
                            state <= CHECK;
                        end
                    end else begin
                        state <= DONE;
                    end
                end

                SUBTRACT: begin
                    if (sub_active) begin
                        if (temp_n >= 24'd10) begin
                            temp_n <= temp_n - 24'd10;
                            sub_count <= sub_count + 24'd1;
                        end else begin
                            // temp_n is now the remainder
                            digit <= temp_n[3:0];
                            sub_active <= 1'b0;
                            state <= CHECK;
                        end
                    end
                end

                CHECK: begin
                    if (digit[0]) begin
                        // Odd digit
                        stored_digit <= {12'd0, digit};
                        state <= MULTIPLY;
                    end else begin
                        // Even digit, get next digit
                        // First, divide temp_n by 10 (integer division)
                        // temp_n currently holds remainder, need original
                        // Actually, we already subtracted in SUBTRACT, temp_n is remainder
                        // We need to use sub_count as the quotient
                        if (sub_count > 24'd0) begin
                            temp_n <= sub_count;
                            sub_count <= 24'd0;
                            state <= PROCESS;
                        end else begin
                            temp_n <= 24'd0;
                            state <= PROCESS;
                        end
                    end
                end

                MULTIPLY: begin
                    result <= result * stored_digit;
                    any_odd <= 1'b1;
                    // Divide temp_n by 10
                    if (sub_count > 24'd0) begin
                        temp_n <= sub_count;
                        sub_count <= 24'd0;
                        state <= PROCESS;
                    end else begin
                        temp_n <= 24'd0;
                        state <= PROCESS;
                    end
                end

                DONE: begin
                    if (!any_odd) begin
                        result <= 16'd0;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    result <= 16'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule