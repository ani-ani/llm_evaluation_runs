module hill_counter(
    input clk,
    input rst_n,
    input start,
    input [15:0] n,
    output reg [31:0] result,
    output reg done
);

    // States
    typedef enum logic [3:0] {
        IDLE,
        DIGITIZE,
        CHECK_HILL,
        COUNT_HILL,
        DONE
    } state_t;

    state_t state;
    reg [3:0] digits [0:3];
    reg [3:0] current_digit;
    reg [3:0] digit_index;
    reg is_hill;
    reg [31:0] count;
    reg [3:0] pos;
    reg [3:0] prev_digit;
    reg phase;
    reg [31:0] dp [0:3][0:9][0:1];
    reg [3:0] i, j, k;
    reg [31:0] temp_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'hFFFFFFFF;
            done <= 1'b0;
            digit_index <= 0;
            is_hill <= 1'b0;
            count <= 0;
            pos <= 0;
            prev_digit <= 0;
            phase <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= DIGITIZE;
                        digit_index <= 0;
                        done <= 1'b0;
                    end
                end
                DIGITIZE: begin
                    if (digit_index < 4) begin
                        current_digit <= n[3:0];
                        digits[digit_index] <= current_digit;
                        n <= n >> 4;
                        digit_index <= digit_index + 1;
                    end else begin
                        state <= CHECK_HILL;
                        digit_index <= 0;
                    end
                end
                CHECK_HILL: begin
                    if (digit_index == 0) begin
                        is_hill <= 1'b1;
                        prev_digit <= digits[0];
                        phase <= 0;
                        digit_index <= digit_index + 1;
                    end else if (digit_index < 4) begin
                        if (phase == 0) begin
                            if (digits[digit_index] < prev_digit) begin
                                phase <= 1;
                            end else if (digits[digit_index] > prev_digit) begin
                                // Still rising
                            end
                        end else begin
                            if (digits[digit_index] > prev_digit) begin
                                is_hill <= 1'b0;
                            end
                        end
                        prev_digit <= digits[digit_index];
                        digit_index <= digit_index + 1;
                    end else begin
                        if (is_hill) begin
                            state <= COUNT_HILL;
                            count <= 0;
                            pos <= 0;
                            prev_digit <= 0;
                            phase <= 0;
                        end else begin
                            result <= 32'hFFFFFFFF;
                            done <= 1'b1;
                            state <= DONE;
                        end
                    end
                end
                COUNT_HILL: begin
                    if (pos == 0) begin
                        for (i = 0; i < 4; i = i + 1) begin
                            for (j = 0; j < 10; j = j + 1) begin
                                for (k = 0; k < 2; k = k + 1) begin
                                    dp[i][j][k] <= 0;
                                end
                            end
                        end
                        for (i = 1; i < 10; i = i + 1) begin
                            dp[0][i][0] <= 1;
                        end
                        pos <= 1;
                    end else if (pos < 4) begin
                        for (i = 0; i < 10; i = i + 1) begin
                            for (j = 0; j < 2; j = j + 1) begin
                                if (dp[pos-1][i][j] > 0) begin
                                    if (j == 0) begin
                                        for (k = i; k < 10; k = k + 1) begin
                                            dp[pos][k][0] <= dp[pos][k][0] + dp[pos-1][i][j];
                                        end
                                        for (k = 0; k < i; k = k + 1) begin
                                            dp[pos][k][1] <= dp[pos][k][1] + dp[pos-1][i][j];
                                        end
                                    end else begin
                                        for (k = 0; k <= i; k = k + 1) begin
                                            dp[pos][k][1] <= dp[pos][k][1] + dp[pos-1][i][j];
                                        end
                                    end
                                end
                            end
                        end
                        pos <= pos + 1;
                    end else begin
                        temp_count <= 0;
                        for (i = 0; i < 10; i = i + 1) begin
                            for (j = 0; j < 2; j = j + 1) begin
                                temp_count <= temp_count + dp[3][i][j];
                            end
                        end
                        count <= temp_count;
                        result <= count;
                        done <= 1'b1;
                        state <= DONE;
                    end
                end
                DONE: begin
                    if (!start) begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule