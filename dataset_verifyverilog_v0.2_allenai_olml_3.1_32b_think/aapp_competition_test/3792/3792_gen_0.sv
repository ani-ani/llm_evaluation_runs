module fair_nut_strings (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_s,
    input [7:0] char_t,
    input [31:0] k,
    output reg [31:0] result,
    output reg done,
    output reg [7:0] char_idx
);

reg [31:0] cur_count;
reg [31:0] total_sum;
reg [7:0] count;
reg [2:0] state; // 3 bits

parameter IDLE = 3'b000;
parameter READ_CHAR = 3'b001;
parameter COMPUTE = 3'b010;
parameter ACCUMULATE = 3'b011;
parameter DONE = 3'b100;

assign result = 32'b0;
assign done = 1'b0;
assign char_idx = 8'b0;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        cur_count <= 32'b1;
        total_sum <= 32'b0;
        count <= 8'b0;
        state <= IDLE;
    end else begin
        case(state)
            IDLE: 
                if (start) begin
                    state <= READ_CHAR;
                end
                else begin
                    state <= IDLE;
                end
            READ_CHAR: 
                state <= COMPUTE;
            COMPUTE: 
                state <= ACCUMULATE;
            ACCUMULATE: 
                bit s = char_s[0];
                bit t = char_t[0];
                bit equal = (s == t);
                if (!equal) begin
                    cur_count <= (cur_count * 2 + 1) > k ? k : (cur_count * 2 + 1);
                end
                total_sum <= total_sum + cur_count;
                count <= count + 1;
                char_idx <= count;
                if (count == 100) begin
                    state <= DONE;
                    done <= 1'b1;
                    result <= total_sum;
                end else begin
                    state <= READ_CHAR; // Loop back to process next character
                end
            DONE: 
                state <= DONE;
        endcase
    end
end
endmodule