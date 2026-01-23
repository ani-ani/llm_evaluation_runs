module remove_occurrences (
    input clk,
    input rst_n, // active-low
    input start,
    input [7:0] target_char,
    input [63:0] input_str,
    output reg [63:0] result_str,
    output reg done
);

reg [3:0] first_pos, last_pos; // 4 bits, initialized to 8 (invalid)
reg [2:0] counter;
reg [2:0] state;

localparam IDLE = 3'b000,
FIND_FIRST = 3'b001,
FIND_LAST = 3'b010,
ASSEMBLE = 3'b011,
DONE = 3'b100;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        first_pos <= 4'b1000; // 8
        last_pos <= 4'b1000;
        counter <= 3'b000;
        state <= IDLE;
        done <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    first_pos <= 4'b1000;
                    last_pos <= 4'b1000;
                    counter <= 3'b000;
                    state <= FIND_FIRST;
                end
                else begin
                    state <= IDLE;
                end
            end

            FIND_FIRST: begin
                counter <= counter + 1'b1;
                case (counter)
                    0: begin
                        if (input_str[7:0] == target_char && first_pos == 4'b1000) begin
                            first_pos <= 4'd0;
                        end
                    end

                    1: begin
                        if (input_str[15:8] == target_char && first_pos == 4'b1000) begin
                            first_pos <= 4'd1;
                        end
                    end

                    2: begin
                        if (input_str[23:16] == target_char && first_pos == 4'b1000) begin
                            first_pos <= 4'd2;
                        end
                    end

                    3: begin
                        if (input_str[31:24] == target_char && first_pos == 4'b1000) begin
                            first_pos <= 4'd3;
                        end
                    end

                    4: begin
                        if (input_str[39:32] == target_char && first_pos == 4'b1000) begin
                            first_pos <= 4'd4;
                        end
                    end

                    5: begin
                        if (input_str[47:40] == target_char && first_pos == 4'b1000) begin
                            first_pos <= 4'd5;
                        end
                    end

                    6: begin
                        if (input_str[55:48] == target_char && first_pos == 4'b1000) begin
                            first_pos <= 4'd6;
                        end
                    end

                    7: begin
                        if (input_str[63:56] == target_char && first_pos == 4'b1000) begin
                            first_pos <= 4'd7;
                        end
                        state <= FIND_LAST;
                    end

                endcase
            end

            FIND_LAST: begin
                counter <= counter + 1'b1;
                case (counter)
                    0: begin
                        if (input_str[7:0] == target_char) begin
                            last_pos <= 4'd0;
                        end
                    end

                    1: begin
                        if (input_str[15:8] == target_char) begin
                            last_pos <= 4'd1;
                        end
                    end

                    2: begin
                        if (input_str[23:16] == target_char) begin
                            last_pos <= 4'd2;
                        end
                    end

                    3: begin
                        if (input_str[31:24] == target_char) begin
                            last_pos <= 4'd3;
                        end
                    end

                    4: begin
                        if (input_str[39:32] == target_char) begin
                            last_pos <= 4'd4;
                        end
                    end

                    5: begin
                        if (input_str[47:40] == target_char) begin
                            last_pos <= 4'd5;
                        end
                    end

                    6: begin
                        if (input_str[55:48] == target_char) begin
                            last_pos <= 4'd6;
                        end
                    end

                    7: begin
                        state <= ASSEMBLE;
                    end

                endcase
            end

            ASSEMBLE: begin
                if (counter == 0) begin
                    if (first_pos == 4'b1000 && last_pos == 4'b1000) begin
                        result_str <= input_str;
                    end else if (first_pos == last_pos && first_pos != 4'b1000) begin

                        if (first_pos == 4'd0) begin
                            result_str[7:0] <= 8'b0;
                        end else begin
                            result_str[7:0] <= input_str[7:0];
                        end

                        if (first_pos == 4'd1) begin
                            result_str[15:8] <= 8'b0;
                        end else begin
                            result_str[15:8] <= input_str[15:8];
                        end

                        if (first_pos == 4'd2) begin
                            result_str[23:16] <= 8'b0;
                        end else begin
                            result_str[23:16] <= input_str[23:16];
                        end

                        if (first_pos == 4'd3) begin
                            result_str[31:24] <= 8'b0;
                        end else begin
                            result_str[31:24] <= input_str[31:24];
                        end

                        if (first_pos == 4'd4) begin
                            result_str[39:32] <= 8'b0;
                        end else begin
                            result_str[39:32] <= input_str[39:32];
                        end

                        if (first_pos == 4'd5) begin
                            result_str[47:40] <= 8'b0;
                        end else begin
                            result_str[47:40] <= input_str[47:40];
                        end

                        if (first_pos == 4'd6) begin
                            result_str[55:48] <= 8'b0;
                        end else begin
                            result_str[55:48] <= input_str[55:48];
                        end

                        if (first_pos == 4'd7) begin
                            result_str[63:56] <= 8'b0;
                        end else begin
                            result_str[63:56] <= input_str[63:56];
                        end

                    end else begin // two occurrences

                        if (first_pos == 4'd0 || last_pos == 4'd0) begin
                            result_str[7:0] <= 8'b0;
                        end else begin
                            result_str[7:0] <= input_str[7:0];
                        end

                        if (first_pos == 4'd1 || last_pos == 4'd1) begin
                            result_str[15:8] <= 8'b0;
                        end else begin
                            result_str[15:8] <= input_str[15:8];
                        end

                        if (first_pos == 4'd2 || last_pos == 4'd2) begin
                            result_str[23:16] <= 8'b0;
                        end else begin
                            result_str[23:16] <= input_str[23:16];
                        end

                        if (first_pos == 4'd3 || last_pos == 4'd3) begin
                            result_str[31:24] <= 8'b0;
                        end else begin
                            result_str[31:24] <= input_str[31:24];
                        end

                        if (first_pos == 4'd4 || last_pos == 4'd4) begin
                            result_str[39:32] <= 8'b0;
                        end else begin
                            result_str[39:32] <= input_str[39:32];
                        end

                        if (first_pos == 4'd5 || last_pos == 4'd5) begin
                            result_str[47:40] <= 8'b0;
                        end else begin
                            result_str[47:40] <= input_str[47:40];
                        end

                        if (first_pos == 4'd6 || last_pos == 4'd6) begin
                            result_str[55:48] <= 8'b0;
                        end else begin
                            result_str[55:48] <= input_str[55:48];
                        end

                        if (first_pos == 4'd7 || last_pos == 4'd7) begin
                            result_str[63:56] <= 8'b0;
                        end else begin
                            result_str[63:56] <= input_str[63:56];
                        end

                    end
                    state <= DONE;
                end
            end

            DONE: begin
                done <= 1'b1;
            end

        endcase
    end
end
endmodule
