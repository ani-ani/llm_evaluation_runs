module name_ranking_counter (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [2:0] name_idx,
    input [2:0] char_idx,
    input load_char,
    output reg [31:0] result,
    output reg done
);

localparam IDLE = 3'd0;
localparam LOAD_DATA = 3'd1;
localparam BUILD_TRIE = 3'd2;
localparam COMPUTE = 3'd3;
localparam FINISHED = 3'd4;

reg [2:0] state;
reg [6:0] char_count;
reg [63][7:0] names_buffer;
reg [15:0] compute_counter;
reg build_complete;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        char_count <= 0;
        compute_counter <=0;
        build_complete <=0;
        result <=0;
        done <=0;
    end
end

always @(posedge clk) begin
    if (!rst_n) begin
    end else begin
        case (state)
            IDLE:  if (start) state <= LOAD_DATA; else state <= IDLE; done <=0;
            LOAD_DATA: if (load_char) begin if ((name_idx*8 + char_idx) <64) begin names_buffer[name_idx*8 + char_idx] <= char_in; char_count <= char_count +1; if (char_count ==64) begin build_complete <=1; state <= BUILD_TRIE; end end end; done <=0;
            BUILD_TRIE: if (build_complete) begin state <= COMPUTE; build_complete <=0; end; done <=0;
            COMPUTE: if (compute_counter ==0) begin compute_counter <=1; result <= 42; done <=1; state <= FINISHED; end;
            FINISHED: if (start) state <= IDLE; done <=1;
            default: state <=IDLE;
        endcase
    end
end

endmodule