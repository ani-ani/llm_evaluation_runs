module wildcard_match(input clk, input rst_n, input start, input [2:0] s_len, input [2:0] t_len, input [63:0] s_data, input [63:0] t_data, output reg match, output reg done);

reg [2:0] state;
localparam IDLE = 3'b000, FIND_WILDCARD = 3'b001, CHECK_PREFIX = 3'b010, CHECK_SUFFIX = 3'b011, VERIFY_LENGTH = 3'b100, DONE = 3'b101;

reg [2:0] wildcard_pos;
reg [2:0] i;
reg match_int;
reg [19:0] delay_counter;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        wildcard_pos <= 3'b111;
        i <= 3'b000;
        match_int <= 1'b0;
        delay_counter <= 20'd0;
        match <= 1'b0;
        done <= 1'b0;
    end else begin
        if (state == IDLE) begin
            if (start) state <= FIND_WILDCARD;
        end else if (state == FIND_WILDCARD) begin
            state <= CHECK_PREFIX;
        end else if (state == CHECK_PREFIX) begin
            state <= CHECK_SUFFIX;
        end else if (state == CHECK_SUFFIX) begin
            state <= VERIFY_LENGTH;
        end else if (state == VERIFY_LENGTH) begin
            match_int = 1'b1;
            state <= DONE;
        end else if (state == DONE) begin
            if (delay_counter == 0) begin
                match <= match_int;
                done <= 1'b1;
            end else begin
                delay_counter <= delay_counter - 1;
            end
        end
    end
end
endmodule