module translator_matcher (input clk, input rst_n, input start, input [3:0] num_translators, input [3:0] num_languages, input [1:0] translator_lang1 [0:15], input [1:0] translator_lang2 [0:15], output reg [3:0] pair1 [0:7], output reg [3:0] pair2 [0:7], output reg [3:0] num_pairs, output reg valid, output reg impossible, output reg done);
localparam IDLE = 3'd0;
localparam CHECK_MATCHING = 3'd1;
localparam FOUND_MATCHING = 3'd2;
localparam IMPOSSIBLE = 3'd3;

reg [2:0] state;
reg [2:0] initial_state;

reg [15:0] paired;

always @(negedge rst_n) begin
    state <= IDLE;
    paired <= 16'b0;
    valid <= 0;
    impossible <= 0;
    done <= 0;
    num_pairs <= 0;
    pair1 <= 0;
    pair2 <= 0;
end

always @(posedge clk) begin
    if (!rst_n) begin
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    if (num_translators[0]) begin
                        state <= IMPOSSIBLE;
                        impossible <= 1;
                        done <= 1;
                    end else begin
                        state <= CHECK_MATCHING;
                        paired <= 16'b0;
                    end
                end
            end
            CHECK_MATCHING: begin
                state <= IMPOSSIBLE;
                impossible <= 1;
                done <= 1;
            end
            FOUND_MATCHING: begin
            end
            IMPOSSIBLE: begin
            end
        endcase
    end
end
endmodule