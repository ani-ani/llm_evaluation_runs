module train_sorter (
    input clk,
    input rst_n,
    input start,
    input [15:0] p_in,
    input [3:0] idx_in,
    output reg [3:0] result,
    output reg done
);
localparam N =16;
reg [3:0] pos [N-1:0];
reg [3:0] load_count;
reg [2:0] state;
reg [3:0] max_len_reg;
reg [3:0] result_reg;
reg done_reg;
localparam IDLE =3'd0, LOAD=3'd1, COMPUTE=3'd2, DONE=3'd3;
always @(posedge clk) begin
    if (!rst_n) begin
        pos[15] <=4'b0; pos[14] <=4'b0; pos[13] <=4'b0; pos[12] <=4'b0;
        pos[11] <=4'b0; pos[10] <=4'b0; pos[9] <=4'b0; pos[8] <=4'b0;
        pos[7] <=4'b0; pos[6] <=4'b0; pos[5] <=4'b0; pos[4] <=4'b0;
        pos[3] <=4'b0; pos[2] <=4'b0; pos[1] <=4'b0; pos[0] <=4'b0;
        load_count <=4'b0;
        state <=3'b0;
        max_len_reg <=4'b0;
        result_reg <=4'b0;
        done_reg <=1'b0;
    end else begin
        case (state)
            IDLE: begin
                if (start) state <= LOAD;
            end
            LOAD: begin
                if (load_count < N) begin
                    pos[p_in -1] <= idx_in;
                    load_count <= load_count +1;
                end else begin
                    state <= COMPUTE;
                end
            end
            COMPUTE: begin
                reg [3:0] lengths [N-1:0];
                reg [3:0] max_len;
                lengths[N-1] =1;
                max_len =1;
                if (pos[14] < pos[15]) lengths[14] = lengths[15] +1; else lengths[14] =1;
                if (lengths[14] > max_len) max_len = lengths[14];
                if (pos[13] < pos[14]) lengths[13] = lengths[14] +1; else lengths[13] =1;
                if (lengths[13] > max_len) max_len = lengths[13];
                if (pos[12] < pos[13]) lengths[12] = lengths[13] +1; else lengths[12] =1;
                if (lengths[12] > max_len) max_len = lengths[12];
                if (pos[11] < pos[12]) lengths[11] = lengths[12] +1; else lengths[11] =1;
                if (lengths[11] > max_len) max_len = lengths[11];
                if (pos[10] < pos[11]) lengths[10] = lengths[11] +1; else lengths[10] =1;
                if (lengths[10] > max_len) max_len = lengths[10];
                if (pos[9] < pos[10]) lengths[9] = lengths[10] +1; else lengths[9] =1;
                if (lengths[9] > max_len) max_len = lengths[9];
                if (pos[8] < pos[9]) lengths[8] = lengths[9] +1; else lengths[8] =1;
                if (lengths[8] > max_len) max_len = lengths[8];
                if (pos[7] < pos[8]) lengths[7] = lengths[8] +1; else lengths[7] =1;
                if (lengths[7] > max_len) max_len = lengths[7];
                if (pos[6] < pos[7]) lengths[6] = lengths[7] +1; else lengths[6] =1;
                if (lengths[6] > max_len) max_len = lengths[6];
                if (pos[5] < pos[6]) lengths[5] = lengths[6] +1; else lengths[5] =1;
                if (lengths[5] > max_len) max_len = lengths[5];
                if (pos[4] < pos[5]) lengths[4] = lengths[5] +1; else lengths[4] =1;
                if (lengths[4] > max_len) max_len = lengths[4];
                if (pos[3] < pos[4]) lengths[3] = lengths[4] +1; else lengths[3] =1;
                if (lengths[3] > max_len) max_len = lengths[3];
                if (pos[2] < pos[3]) lengths[2] = lengths[3] +1; else lengths[2] =1;
                if (lengths[2] > max_len) max_len = lengths[2];
                if (pos[1] < pos[2]) lengths[1] = lengths[2] +1; else lengths[1] =1;
                if (lengths[1] > max_len) max_len = lengths[1];
                if (pos[0] < pos[1]) lengths[0] = lengths[1] +1; else lengths[0] =1;
                if (lengths[0] > max_len) max_len = lengths[0];
                max_len_reg <= max_len;
                result_reg <= N - max_len;
                done_reg <=1'b1;
                state <= DONE;
            end
            DONE: begin
            end
        endcase
    end
end
assign result = result_reg;
assign done = done_reg;
endmodule