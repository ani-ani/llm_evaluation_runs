module k_incremental_double_free (
input clk,
input rst_n,
input start,
input [5:0] k_in,
input [63:0] n_in,
output reg [7:0] char_out,
output reg char_valid,
output reg done,
output reg error
);

parameter IDLE = 3'b000;
parameter FIND_PAIR = 3'b001;
parameter STREAM = 3'b010;
parameter FINISHED = 3'b100;

reg [2:0] state;
reg [63:0] n_val;
reg [7:0] current_char1;
reg [63:0] current_remaining;
reg [7:0] char1, char2;
reg [7:0] stream_pos;
reg str_type;
reg [63:0] pair_index;
reg error;
reg done;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
n_val <= 0;
current_char1 <=0;
current_remaining <=0;
char1 <=0;
char2 <=0;
stream_pos <=0;
str_type <=0;
pair_index <=0;
char_valid <=0;
char_out <=8'b0;
done <=0;
error <=0;
    end else begin
        case (state)
            IDLE: begin
                char_valid <=0;
done <=0;
error <=0;
char_out <=8'b0;
if (start) begin
                    if (k_in != 2) begin
                        error <=1;
state <= FINISHED;
                    end else if (n_in <1 || n_in >650) begin
                        error <=1;
state <= FINISHED;
                    end else begin
                        n_val <= n_in;
pair_index <= n_val -1;
str_type <= (n_val -1) % 2;
state <= FIND_PAIR;
                    end
                end
            end

            FIND_PAIR: begin
                char_valid <=0;
char_out <=8'b0;
if (current_char1 ==0) begin
                    current_char1 <=0;
current_remaining <= pair_index;
                end else begin
                    if (25 - current_char1 > current_remaining) begin
                        char1 <= current_char1;
char2 <= current_char1 +1 + current_remaining;
state <= STREAM;
                    end else begin
                        current_remaining <= current_remaining - (25 - current_char1);
current_char1 <= current_char1 +1;
                    end
                end
            end

            STREAM: begin
                char_valid <=1;
done <=0;
char_out <=8'b0;
if (stream_pos ==0) begin
                    char_out <= (str_type ==0) ? char1 : char2;
stream_pos <=1;
                end else if (stream_pos ==1) begin
                    char_out <= char2;
stream_pos <=2;
                end else begin // stream_pos ==2
                    char_out <= (str_type ==0) ? char1 : char2;
stream_pos <=3;
state <= FINISHED;
done <=1;
                end
            end

            FINISHED: begin
                char_valid <=0;
char_out <=8'b0;
            end
        endcase
    end
endmodule