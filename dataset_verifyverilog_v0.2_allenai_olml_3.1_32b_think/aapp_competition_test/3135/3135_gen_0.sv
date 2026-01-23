module signed_binary_converter (input clk, input rst_n, input start, input [15:0] binary_in, output reg [17:0] signed_out, output reg [4:0] length, output reg done);
reg [1:0] state;
reg [4:0] counter;
reg [4:0] length_val;
reg done_flag;

always @(*) begin
    state <= 2'b00;
    counter <= 0;
    length_val <= 0;
    done_flag <= 0;
end

always @(posedge clk) begin
    if (!rst_n) begin
        state <= 2'b00;
        counter <= 0;
        length_val <= 0;
        done_flag <= 0;
    end else begin
        case (state)
            2'b00: if (start) begin
                state <= 2'b01;
                counter <= 0;
                length_val <= 0;
                done_flag <= 0;
            end
            2'b01: if (counter < 18) begin
                counter <= counter + 1;
            end else begin
                state <= 2'b10;
                done_flag <= 1;
                length_val <= 18;
            end
            2'b10: begin
                state <= 2'b10;
                done_flag <= 1;
            end
        endcase
    end
end

assign signed_out = 0;
assign length = length_val;
assign done = done_flag;
endmodule