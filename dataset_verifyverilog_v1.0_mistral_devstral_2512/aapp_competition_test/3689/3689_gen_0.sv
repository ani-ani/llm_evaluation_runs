module beautiful_number(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] k,
    input [3:0] digits [0:15],
    output reg [3:0] m,
    output reg [3:0] y_digits [0:15],
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] COMPARE = 3'd2;
    localparam [2:0] INCREMENT = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state;
    reg [3:0] pattern [0:7];
    reg [3:0] i, j;
    reg [3:0] carry;
    reg [1:0] cmp_flag;
    reg [3:0] pattern_digit;
    reg [3:0] input_digit;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            m <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                y_digits[i] <= 4'd0;
            end
            for (i = 0; i < 8; i = i + 1) begin
                pattern[i] <= 4'd0;
            end
            i <= 4'd0;
            j <= 4'd0;
            carry <= 4'd0;
            cmp_flag <= 2'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        for (i = 0; i < 8; i = i + 1) begin
                            if (i < k) begin
                                pattern[i] <= digits[i];
                            end else begin
                                pattern[i] <= 4'd0;
                            end
                        end
                        i <= 4'd0;
                        cmp_flag <= 2'd0;
                        state <= INIT;
                        done <= 1'b0;
                    end
                end

                INIT: begin
                    i <= 4'd0;
                    state <= COMPARE;
                end

                COMPARE: begin
                    if (i < n) begin
                        if (i < k) begin
                            pattern_digit <= pattern[i];
                        end else begin
                            pattern_digit <= pattern[i - k];
                        end
                        input_digit <= digits[i];

                        if (cmp_flag == 2'd0) begin
                            if (input_digit > pattern_digit) begin
                                cmp_flag <= 2'd1;
                            end else if (input_digit < pattern_digit) begin
                                cmp_flag <= 2'd2;
                            end
                        end
                        i <= i + 1;
                    end else begin
                        if (cmp_flag == 2'd1) begin
                            i <= k - 1;
                            carry <= 4'd1;
                            state <= INCREMENT;
                        end else begin
                            state <= OUTPUT;
                        end
                    end
                end

                INCREMENT: begin
                    if (i < 8 && i >= 0 && carry > 0) begin
                        if (pattern[i] + carry >= 10) begin
                            pattern[i] <= pattern[i] + carry - 10;
                            carry <= 4'd1;
                        end else begin
                            pattern[i] <= pattern[i] + carry;
                            carry <= 4'd0;
                        end

                        if (i == 0 && carry > 0) begin
                            pattern[0] <= 4'd1;
                            for (j = 1; j < 8; j = j + 1) begin
                                if (j < k) begin
                                    pattern[j] <= 4'd0;
                                end
                            end
                            state <= OUTPUT;
                        end else if (carry > 0) begin
                            i <= i - 1;
                        end else begin
                            state <= OUTPUT;
                        end
                    end else begin
                        state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    m <= n;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < n) begin
                            if (i < k) begin
                                y_digits[i] <= pattern[i];
                            end else begin
                                y_digits[i] <= pattern[i - k];
                            end
                        end else begin
                            y_digits[i] <= 4'd0;
                        end
                    end
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule