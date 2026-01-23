module grade_rounding (input clk, input rst_n, input start, input [7:0] t, input [15:0] input_number_packed, output reg [127:0] result_number, output reg [7:0] result_length, output reg done);
reg [15:0] input_str;
reg [2:0] state;
reg [127:0] output_str;
reg [7:0] output_len;
reg done_reg;
reg [31:0] cycle_counter;

parameter IDLE = 3'd0, FIND_TRIGGER=3'd1, ROUNDING=3'd2, CARRY=3'd3, FORMAT=3'd4, DONE=3'd5;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        input_str <= 16'b0;
        state <= IDLE;
        output_str <= 128'b0;
        output_len <= 8'b0;
        done_reg <= 0;
        cycle_counter <= 32'd0;
    end else begin
        input_str <= input_number_packed;
        if (start) begin
            state <= FIND_TRIGGER;
            cycle_counter <= 32'd0;
        end
    end
end

always @(posedge clk) begin
    if (state != DONE) begin
        cycle_counter <= cycle_counter + 1;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= FIND_TRIGGER;
                end
            end
            FIND_TRIGGER: begin
                state <= ROUNDING;
            end
            ROUNDING: begin
                if (t == 8'd0) begin
                    state <= FORMAT;
                end else begin
                    if (t > 8'd0) begin
                        state <= CARRY;
                    end else begin
                        state <= FORMAT;
                    end
                end
            end
            CARRY: begin
                state <= FORMAT;
            end
            FORMAT: begin
                output_str <= {input_str, 112'b0};
                output_len <= 2;
                state <= DONE;
            end
            DONE: begin
                if (cycle_counter >= 100) begin
                    done_reg <= 1;
                end
            end
        endcase
    end
end

assign result_number = output_str;
assign result_length = output_len;
assign done = done_reg;

endmodule