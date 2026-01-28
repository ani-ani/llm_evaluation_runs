module divisor_counter (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [7:0] counter;
    reg [7:0] divisor_count;
    reg [7:0] n_reg;
    reg [7:0] divisor;
    reg [7:0] remainder;
    reg [7:0] temp_n;
    reg [7:0] temp_divisor;
    reg computing_division;

    // Sequential logic with reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 8'd0;
            divisor_count <= 8'd0;
            n_reg <= 8'd0;
            result <= 8'd0;
            done <= 1'b0;
            divisor <= 8'd0;
            remainder <= 8'd0;
            temp_n <= 8'd0;
            temp_divisor <= 8'd0;
            computing_division <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        n_reg <= n;
                        counter <= 8'd1;
                        divisor_count <= 8'd0;
                        if (n == 8'd0) begin
                            state <= FINISH;
                        end else begin
                            state <= COMPUTE;
                        end
                    end
                end

                COMPUTE: begin
                    // Division simulation: check if counter divides n_reg
                    if (!computing_division) begin
                        temp_n <= n_reg;
                        temp_divisor <= counter;
                        remainder <= 8'd0;
                        computing_division <= 1'b1;
                    end else begin
                        // Simple repeated subtraction for division
                        if (temp_n >= temp_divisor) begin
                            temp_n <= temp_n - temp_divisor;
                            remainder <= remainder + 8'd1;
                        end else begin
                            // Division complete
                            computing_division <= 1'b0;
                            // Check if remainder is 0 (divisible)
                            if (temp_n == 8'd0) begin
                                divisor_count <= divisor_count + 8'd1;
                            end
                            // Move to next number or finish
                            if (counter < n_reg) begin
                                counter <= counter + 8'd1;
                            end else begin
                                state <= FINISH;
                            end
                        end
                    end
                end

                FINISH: begin
                    result <= divisor_count;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule