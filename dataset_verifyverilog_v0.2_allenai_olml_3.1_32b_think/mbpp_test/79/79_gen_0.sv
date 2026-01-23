module word_len_checker (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [7:0] char_in,
    input char_valid,
    input char_last,
    output reg result,
    output reg done
);

reg [4:0] current_length;
reg result_reg;
reg [1:0] state;
reg [4:0] char_count;

localparam IDLE = 2'd0;
localparam READING = 2'd1;
localparam DONE = 2'd2;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_length <= 4'd0;
        result_reg <= 1'b0;
        state <= IDLE;
        char_count <= 5'd0;
        done <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= READING;
                end else begin
                    state <= IDLE;
                end
            end
            READING: begin
                if (char_valid) begin
                    if (char_in == 8'h20) begin // space
                        if (current_length[0] == 1) begin
                            result_reg <= result_reg | 1'b1;
                        end
                        current_length <= 4'd0;
                    end else begin // non-space
                        current_length <= (current_length == 4'd15) ? 4'd15 : current_length + 1;
                    end
                    char_count <= char_count + 1;

                    if (char_last) begin
                        state <= DONE;
                    end else begin
                        state <= READING;
                    end
                end else begin // no valid character, stay in READING
                    state <= READING;
                end
            end
            DONE: state <= DONE;
        endcase

        done <= (state == DONE);
    end
end

assign result = result_reg;

endmodule