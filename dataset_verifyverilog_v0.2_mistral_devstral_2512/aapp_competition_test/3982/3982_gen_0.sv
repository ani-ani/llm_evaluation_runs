module morse_decoder (
    input clk,
    input rst_n,
    input start,
    input bit_in,
    output reg [31:0] result,
    output reg done
);

    parameter MOD = 32'h3B9ACA07;
    parameter IDLE = 2'b00;
    parameter CALCULATE = 2'b01;
    parameter DONE = 2'b10;

    reg [1:0] state = IDLE;
    reg [11:0] buffer = 0;
    reg [3:0] buffer_len = 0;
    reg [31:0] dp [0:11];
    reg [4:0] loop_counter = 0;
    reg [3:0] inner_counter = 0;
    reg [3:0] temp_substr = 0;
    reg [31:0] temp_sum = 0;
    reg [31:0] total = 0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            buffer <= 0;
            buffer_len <= 0;
            result <= 0;
            done <= 0;
            loop_counter <= 0;
            inner_counter <= 0;
            temp_substr <= 0;
            temp_sum <= 0;
            total <= 0;
            for (int i = 0; i < 12; i = i + 1) begin
                dp[i] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        buffer <= {buffer[10:0], bit_in};
                        buffer_len <= buffer_len + 1;
                        state <= CALCULATE;
                        loop_counter <= 0;
                        inner_counter <= 0;
                        temp_substr <= 0;
                        temp_sum <= 0;
                        total <= 0;
                    end
                end
                CALCULATE: begin
                    if (loop_counter < buffer_len) begin
                        if (inner_counter == 0) begin
                            dp[loop_counter] <= 0;
                            inner_counter <= inner_counter + 1;
                        end else if (inner_counter <= loop_counter) begin
                            temp_substr <= buffer[loop_counter - inner_counter + 1 : loop_counter - inner_counter + 4];
                            if (is_valid_code(temp_substr, inner_counter)) begin
                                if (loop_counter - inner_counter == 0) begin
                                    dp[loop_counter] <= (dp[loop_counter] + 1) % MOD;
                                end else begin
                                    dp[loop_counter] <= (dp[loop_counter] + dp[loop_counter - inner_counter]) % MOD;
                                end
                            end
                            inner_counter <= inner_counter + 1;
                        end else begin
                            temp_sum <= (temp_sum + dp[loop_counter]) % MOD;
                            loop_counter <= loop_counter + 1;
                            inner_counter <= 0;
                        end
                    end else begin
                        total <= temp_sum;
                        state <= DONE;
                    end
                end
                DONE: begin
                    result <= total;
                    done <= 1;
                    state <= IDLE;
                    done <= 0;
                end
            endcase
        end
    end

    function automatic bit is_valid_code;
        input [3:0] code;
        input [3:0] len;
        begin
            case (len)
                1: is_valid_code = 1;
                2: is_valid_code = 1;
                3: is_valid_code = 1;
                4: is_valid_code = !(code == 4'b0011 || code == 4'b0101 || code == 4'b1110 || code == 4'b1111);
                default: is_valid_code = 0;
            endcase
        end
    endfunction

endmodule