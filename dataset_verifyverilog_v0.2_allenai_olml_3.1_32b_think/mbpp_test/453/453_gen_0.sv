module sum_even_factors(input clk, input rst_n, input start, input [5:0] n, output reg [7:0] result, output reg done);
parameter MAX_ITER = 16;
reg [7:0] total_product;
reg [6:0] temp_n;
reg [4:0] i;
reg [4:0] exponent_count;
reg [2:0] state;
reg [15:0] contribution;
localparam IDLE = 3'b000, CHECK_ODD = 3'b001, FACTOR_LOOP = 3'b010, ITERATE_I = 3'b011, DIVIDE_CHECK = 3'b100, COMPUTE_SUM = 3'b101, MULTIPLY_RESULT = 3'b110, DONE = 3'b111;
always @(*) begin
    result = 8'b0;
    done = 1'b0;
end
always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        total_product <= 8'b1;
        temp_n <= 6'b0;
        i <= 4'b0;
        exponent_count <= 5'b0;
        contribution <= 16'b0;
    end else begin
        case (state)
            IDLE: begin
                if (start == 1'b1) state <= CHECK_ODD;
                else state <= IDLE;
            end
            CHECK_ODD: begin
                if (n % 2 == 1) begin
                    result <= 8'b0;
                    done <= 1'b1;
                    state <= DONE;
                end else begin
                    temp_n <= n;
                    i <= 2;
                    exponent_count <= 5'b0;
                    state <= FACTOR_LOOP;
                end
            end
            FACTOR_LOOP: begin
                if (i > MAX_ITER || i*i > temp_n) begin
                    if (temp_n >= 2) begin
                        total_product <= total_product * (temp_n + 1);
                        state <= DONE;
                    end else begin
                        state <= DONE;
                    end
                end else begin
                    if (temp_n % i == 0) begin
                        exponent_count <= 1;
                        temp_n <= temp_n / i;
                        if (temp_n % i == 0) state <= DIVIDE_CHECK;
                        else state <= COMPUTE_SUM;
                    end else begin
                        i <= i + 1;
                        state <= ITERATE_I;
                    end
                end
            end
            ITERATE_I: state <= FACTOR_LOOP;
            DIVIDE_CHECK: begin
                exponent_count <= exponent_count + 1;
                temp_n <= temp_n / i;
                if (temp_n % i == 0) state <= DIVIDE_CHECK;
                else state <= COMPUTE_SUM;
            end
            COMPUTE_SUM: begin
                if (i == 2) begin
                    total_product <= total_product * ((1 << (exponent_count + 1)) - 2);
                end else begin
                    case (exponent_count)
                        1: contribution = 1 + i;
                        2: contribution = 1 + i + i*i;
                        3: contribution = 1 + i + i*i + i*i*i;
                        4: contribution = 1 + i + i*i + i*i*i + i*i*i*i;
                        5: contribution = 1 + i + i*i + i*i*i + i*i*i*i + i*i*i*i*i;
                        default: contribution = 1;
                    endcase
                    total_product <= total_product * contribution;
                end
                i <= i + 1;
                state <= FACTOR_LOOP;
            end
            MULTIPLY_RESULT: state <= DONE;
            DONE: begin
                result <= total_product;
                done <= 1'b1;
                state <= DONE;
            end
        endcase
    end
end
endmodule