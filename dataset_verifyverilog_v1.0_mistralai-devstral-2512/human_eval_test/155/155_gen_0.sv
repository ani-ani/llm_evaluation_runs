module digit_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [15:0] num,
    output reg [3:0] even_count,
    output reg [3:0] odd_count,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] ABS = 3'd1;
    localparam [2:0] ZERO_CHECK = 3'd2;
    localparam [2:0] EXTRACT = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [15:0] abs_num;
    reg [15:0] current_num;
    reg [3:0] digit;
    reg [3:0] extraction_count;
    reg [3:0] i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            abs_num <= 16'd0;
            current_num <= 16'd0;
            digit <= 4'd0;
            extraction_count <= 4'd0;
            even_count <= 4'd0;
            odd_count <= 4'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        case (state)
            IDLE: begin
                next_state = IDLE;
                done = 1'b0;
                if (start) begin
                    next_state = ABS;
                end
            end

            ABS: begin
                next_state = ZERO_CHECK;
                if (num[15]) begin
                    abs_num = ~num + 16'd1;
                end else begin
                    abs_num = num;
                end
            end

            ZERO_CHECK: begin
                next_state = EXTRACT;
                if (abs_num == 16'd0) begin
                    even_count = 4'd1;
                    odd_count = 4'd0;
                    next_state = DONE_STATE;
                end else begin
                    current_num = abs_num;
                    extraction_count = 4'd0;
                    even_count = 4'd0;
                    odd_count = 4'd0;
                end
            end

            EXTRACT: begin
                next_state = EXTRACT;
                digit = current_num % 10;
                current_num = current_num / 10;
                extraction_count = extraction_count + 4'd1;

                if (digit == 4'd0 || digit == 4'd2 || digit == 4'd4 || digit == 4'd6 || digit == 4'd8) begin
                    even_count = even_count + 4'd1;
                end else begin
                    odd_count = odd_count + 4'd1;
                end

                if (current_num == 16'd0 || extraction_count == 4'd5) begin
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
                done = 1'b1;
            end

            default: begin
                next_state = IDLE;
                done = 1'b0;
            end
        endcase
    end

endmodule