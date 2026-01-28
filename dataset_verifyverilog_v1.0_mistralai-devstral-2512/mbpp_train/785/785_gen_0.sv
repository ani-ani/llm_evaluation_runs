module TupleParser(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input char_valid,
    output reg [15:0] result [0:3],
    output reg result_valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] WAIT_OPEN  = 3'd1;
    localparam [2:0] PARSING_NUM = 3'd2;
    localparam [2:0] SKIP_SPACE = 3'd3;
    localparam [2:0] SKIP_COMMA = 3'd4;
    localparam [2:0] WAIT_CLOSE = 3'd5;
    localparam [2:0] FINISH     = 3'd6;

    reg [2:0] state, next_state;
    reg [15:0] current_num;
    reg [3:0] num_index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_num <= 16'd0;
            num_index <= 4'd0;
            cycle_count <= 8'd0;
            result_valid <= 1'b0;
            done <= 1'b1;
            result[0] <= 16'd0;
            result[1] <= 16'd0;
            result[2] <= 16'd0;
            result[3] <= 16'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b1;
                    result_valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= WAIT_OPEN;
                        done <= 1'b0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                WAIT_OPEN: begin
                    if (char_valid) begin
                        if (char_in == 8'd40) begin  // '('
                            next_state <= PARSING_NUM;
                            current_num <= 16'd0;
                            num_index <= 4'd0;
                        end
                    end
                end

                PARSING_NUM: begin
                    if (char_valid) begin
                        if (char_in >= 8'd48 && char_in <= 8'd57) begin  // '0'-'9'
                            current_num <= current_num * 16'd10 + (char_in - 8'd48);
                        end else if (char_in == 8'd44) begin  // ','
                            result[num_index] <= current_num;
                            num_index <= num_index + 4'd1;
                            next_state <= SKIP_SPACE;
                        end else if (char_in == 8'd41) begin  // ')'
                            result[num_index] <= current_num;
                            next_state <= FINISH;
                        end
                    end
                end

                SKIP_SPACE: begin
                    if (char_valid) begin
                        if (char_in == 8'd32) begin  // ' '
                            next_state <= SKIP_COMMA;
                        end
                    end
                end

                SKIP_COMMA: begin
                    if (char_valid) begin
                        if (char_in == 8'd44) begin  // ','
                            next_state <= PARSING_NUM;
                            current_num <= 16'd0;
                        end
                    end
                end

                WAIT_CLOSE: begin
                    if (char_valid) begin
                        if (char_in == 8'd41) begin  // ')'
                            next_state <= FINISH;
                        end
                    end
                end

                FINISH: begin
                    result_valid <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase

            if (state != IDLE && state != FINISH) begin
                cycle_count <= cycle_count + 8'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    next_state <= IDLE;
                end
            end
        end
    end

endmodule