module server_cost_calculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] factor_str [0:15],
    input wire [3:0] str_len,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [31:0] MAX_ITER = 32'd4096;

    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PARSE = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    // Registers
    reg [2:0] state, next_state;
    reg [31:0] K;
    reg [31:0] min_cost;
    reg [31:0] i;
    reg [31:0] current_factor;
    reg [3:0] parse_index;
    reg [7:0] current_char;
    reg [3:0] digit_count;
    reg [7:0] temp_digit;
    reg factor_ready;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            K <= 32'd1;
            min_cost <= 32'd0;
            i <= 32'd0;
            current_factor <= 32'd0;
            parse_index <= 4'd0;
            current_char <= 8'd0;
            digit_count <= 4'd0;
            temp_digit <= 8'd0;
            factor_ready <= 1'b0;
            done <= 1'b0;
            result <= 32'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PARSE;
                end
            end
            PARSE: begin
                if (parse_index >= str_len) begin
                    if (digit_count > 0) begin
                        factor_ready = 1'b1;
                    end
                    if (factor_ready) begin
                        next_state = COMPUTE;
                    end
                end
            end
            COMPUTE: begin
                if (i >= MAX_ITER || i > K) begin
                    next_state = FINISH;
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Parsing logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            parse_index <= 4'd0;
            current_char <= 8'd0;
            digit_count <= 4'd0;
            temp_digit <= 8'd0;
            factor_ready <= 1'b0;
        end else begin
            if (state == PARSE) begin
                current_char = factor_str[parse_index];
                if (current_char >= 8'd48 && current_char <= 8'd57) begin
                    temp_digit = current_char - 8'd48;
                    if (digit_count == 0) begin
                        current_factor = temp_digit;
                        digit_count = 4'd1;
                    end else begin
                        current_factor = current_factor * 10 + temp_digit;
                        digit_count = 4'd2;
                        factor_ready = 1'b1;
                    end
                end
                parse_index = parse_index + 4'd1;
                if (factor_ready) begin
                    K = K * current_factor;
                    current_factor = 32'd0;
                    digit_count = 4'd0;
                    factor_ready = 1'b0;
                end
            end
        end
    end

    // Compute logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i <= 32'd1;
            min_cost <= 32'd1000000000;
        end else begin
            if (state == COMPUTE) begin
                if (i > 32'd1 && K % i == 0) begin
                    if (i + (K / i) < min_cost) begin
                        min_cost = i + (K / i);
                    end
                end
                i = i + 32'd1;
            end else if (state == FINISH) begin
                result = min_cost % MOD;
                done = 1'b1;
            end else begin
                done = 1'b0;
            end
        end
    end

endmodule