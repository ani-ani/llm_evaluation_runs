module almost_palindrome_counter (
    input clk,
    input rst_n,
    input start,
    input [4:0] length_in,
    input [127:0] char_flat,
    output reg [15:0] result,
    output reg done
); 
reg [1:0] state; // 0:IDLE, 1:COUNTING, 2:DONE 
reg [3:0] i_count, j_count; 
reg [15:0] total; 
reg [3:0] temp; 
always @(posedge clk or !rst_n) begin 
    if (!rst_n) begin 
        state <= 2'b00; 
        i_count <= 4'd0; 
        j_count <= 4'd0; 
        total <= 16'd0; 
        done <= 1'b0; 
    end else begin 
        if (state == 2'b00) begin 
            if (start == 1) begin 
                state <= 2'b01; 
                i_count <= 4'd0; 
                j_count <= 4'd0; 
            end 
        end else if (state == 2'b01) begin 
            if (i_count < length_in) begin 
                if (j_count < i_count) begin 
                    j_count <= i_count; 
                end else if (j_count < length_in) begin 
                    j_count <= j_count + 1; 
                end else begin 
                    i_count <= i_count + 1; 
                    j_count <= i_count; 
                end 
            end else begin 
                state <= 2'b10; 
                done <= 1'b1; 
            end 
        end 
    end 
end 
assign result = total; 
assign done = state == 2'b10 ? 1'b1 : 1'b0; 
endmodule