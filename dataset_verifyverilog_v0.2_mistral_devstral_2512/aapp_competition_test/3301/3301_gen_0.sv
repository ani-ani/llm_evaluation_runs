module swerc_fee_calculator (
    input clk,
    input rst_n,
    input start,
    input signed [15:0] swerc_cost,
    input [3:0] swerc_hops,
    input signed [15:0] comp_cost,
    input [3:0] comp_hops,
    output reg [15:0] result,
    output reg [1:0] status,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'b00;
    localparam [1:0] CHECK = 2'b01;
    localparam [1:0] DIVIDE = 2'b10;
    localparam [1:0] DONE = 2'b11;

    reg [1:0] state;
    reg [15:0] numerator;
    reg [3:0] denominator;
    reg [15:0] quotient;
    reg [15:0] remainder;
    reg [3:0] div_counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'b0;
            status <= 2'b00;
            done <= 1'b0;
            numerator <= 16'b0;
            denominator <= 4'b0;
            quotient <= 16'b0;
            remainder <= 16'b0;
            div_counter <= 4'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= CHECK;
                        status <= 2'b00;
                        done <= 1'b0;
                    end
                end
                CHECK: begin
                    if (comp_hops <= swerc_hops) begin
                        status <= 2'b11; // Impossible
                        state <= DONE;
                    end else begin
                        numerator <= comp_cost - swerc_cost;
                        denominator <= comp_hops - swerc_hops;
                        if (numerator[15]) begin // numerator < 0
                            status <= 2'b10; // Infinity
                            state <= DONE;
                        end else begin
                            state <= DIVIDE;
                            quotient <= 16'b0;
                            remainder <= numerator;
                            div_counter <= denominator;
                        end
                    end
                end
                DIVIDE: begin
                    if (div_counter == 0) begin
                        result <= quotient;
                        status <= 2'b01; // Valid
                        state <= DONE;
                    end else begin
                        if (remainder >= div_counter) begin
                            remainder <= remainder - div_counter;
                            quotient <= quotient + 1;
                        end
                        div_counter <= div_counter - 1;
                    end
                end
                DONE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule