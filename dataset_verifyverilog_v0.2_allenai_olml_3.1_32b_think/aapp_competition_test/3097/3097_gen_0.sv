module table_counter (
    input clk,
    input rst_n, // active low
    input start,
    input [9:0] query_low,
    input [9:0] query_high,
    output reg [15:0] count,
    output reg done
);

localparam IDLE = 3'd0,
FETCH_START =3'd1,
COMPUTE_ROW =3'd2,
NEXT_ROW =3'd3,
DONE =3'd4;

reg [2:0] state;
reg [3:0] current_row;
reg [11:0] current_val;
reg [3:0] row_step;
reg [15:0] count;
reg done;

reg [15:0] next_val;

function [11:0] rev;
input [11:0] x;
integer digit2, digit1, digit0;
if (x ==0) begin
    digit2 =0; digit1=0; digit0=0;
end else begin
    digit2 = x / 100;
digit1 = (x % 100)/10;
digit0 = x %10;
end
if (digit2 !=0) begin
    rev = digit0 * 100 + digit1 *10 + digit2;
end else if (digit1 !=0) begin
    rev = digit0 *10 + digit1;
end else begin
    rev = digit0;
end
endfunction

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        current_row <=0;
        current_val <=0;
        row_step <=0;
        count <=0;
        done <=0;
    end else begin
        if (state == IDLE) begin
            if (start) begin
                state <= FETCH_START;
            end
        end else if (state == FETCH_START) begin
            current_row <=1;
            current_val <=1;
            row_step <=0;
            state <= COMPUTE_ROW;
        end else if (state == COMPUTE_ROW) begin
            if ( (current_val >= query_low) && (current_val <= query_high) ) begin
                count <= count +1;
            end
            next_val = current_val + rev(current_val);
            if (row_step <15) begin
                row_step <= row_step +1;
                current_val <= next_val;
                state <= COMPUTE_ROW;
            end else begin
                state <= NEXT_ROW;
            end
        end else if (state == NEXT_ROW) begin
            current_row <= current_row +1;
            if (current_row >16) begin
                done <=1;
                state <= DONE;
            end else begin
                row_step <=0;
                current_val <= current_row;
                state <= COMPUTE_ROW;
            end
        end else if (state == DONE) begin
            // stay
        end
    end
end

endmodule