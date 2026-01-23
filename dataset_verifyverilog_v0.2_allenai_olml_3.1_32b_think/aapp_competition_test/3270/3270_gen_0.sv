module word_ladder_optimizer (
input wire clock,
input wire reset,
input wire start,
input wire [31:0] dict [7:0],
output reg [31:0] result_word,
output reg [7:0] result_steps,
output reg done
);

reg [31:0] dict_reg [7:0];
reg [2:0] state;
reg [15:0] counter;

localparam IDLE = 3'd0;
localparam BUILD_GRAPH = 3'd1;
localparam BASELINE = 3'd2;
localparam EVALUATE = 3'd3;
localparam DONE_STATE = 3'd4;

always @(posedge clock) begin
    if (reset) begin
        state <= IDLE;
        dict_reg <= 0;
        counter <= 0;
        result_word <= 32'd0;
        result_steps <= 8'd0;
        done <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    dict_reg <= dict;
                    state <= BUILD_GRAPH;
                    counter <= 0;
                end
            end
            BUILD_GRAPH: begin
                counter <= counter + 1;
                if (counter > 10) state <= BASELINE;
            end
            BASELINE: begin
                counter <= counter + 1;
                if (counter > 5) state <= EVALUATE;
            end
            EVALUATE: begin
                counter <= counter + 1;
                if (counter > 50) state <= DONE_STATE;
            end
            DONE_STATE: begin
                done <= 1'b1;
                result_word <= 32'd0;
                result_steps <= 8'd0;
            end
        endcase
    end
end

endmodule