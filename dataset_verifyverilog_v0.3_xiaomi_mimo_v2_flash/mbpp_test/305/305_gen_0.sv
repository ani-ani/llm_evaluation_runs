module word_finder (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in [0:31],
    output reg [7:0] word1 [0:7],
    output reg [7:0] word2 [0:7],
    output reg found,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SEARCH_START = 3'd1;
    localparam [2:0] CAPTURE_W1 = 3'd2;
    localparam [2:0] CAPTURE_W2 = 3'd3;
    localparam [2:0] FINISHED = 3'd4;

    reg [2:0] state;
    reg [5:0] idx;
    reg [5:0] w1_idx;
    reg [5:0] w2_idx;
    reg space_seen;
    reg w1_has_p;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            found <= 1'b0;
            done <= 1'b0;
            idx <= 6'd0;
            w1_idx <= 6'd0;
            w2_idx <= 6'd0;
            space_seen <= 1'b0;
            w1_has_p <= 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                word1[i] <= 8'd0;
                word2[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= SEARCH_START;
                        idx <= 6'd0;
                        w1_idx <= 6'd0;
                        w2_idx <= 6'd0;
                        space_seen <= 1'b0;
                        w1_has_p <= 1'b0;
                        for (i = 0; i < 8; i = i + 1) begin
                            word1[i] <= 8'd0;
                            word2[i] <= 8'd0;
                        end
                    end
                end

                SEARCH_START: begin
                    if (idx < 6'd32) begin
                        if ((char_in[idx] == 8'h50 || char_in[idx] == 8'h70) && !space_seen) begin
                            w1_has_p <= 1'b1;
                            word1[0] <= char_in[idx];
                            w1_idx <= 6'd1;
                            state <= CAPTURE_W1;
                        end else if (char_in[idx] == 8'h20 && w1_has_p && w1_idx > 6'd0) begin
                            space_seen <= 1'b1;
                            state <= CAPTURE_W2;
                            w2_idx <= 6'd0;
                        end else if (char_in[idx] == 8'h20 && !w1_has_p) begin
                            state <= SEARCH_START;
                        end else if (char_in[idx] != 8'h20 && w1_has_p && !space_seen) begin
                            if (w1_idx < 6'd8) begin
                                word1[w1_idx] <= char_in[idx];
                                w1_idx <= w1_idx + 6'd1;
                            end
                            state <= CAPTURE_W1;
                        end
                        idx <= idx + 6'd1;
                    end else begin
                        state <= FINISHED;
                        found <= 1'b0;
                    end
                end

                CAPTURE_W1: begin
                    if (idx < 6'd32) begin
                        if (char_in[idx] == 8'h20) begin
                            space_seen <= 1'b1;
                            state <= CAPTURE_W2;
                            w2_idx <= 6'd0;
                            idx <= idx + 6'd1;
                        end else begin
                            if (w1_idx < 6'd8) begin
                                word1[w1_idx] <= char_in[idx];
                                w1_idx <= w1_idx + 6'd1;
                            end
                            idx <= idx + 6'd1;
                        end
                    end else begin
                        state <= FINISHED;
                        found <= 1'b0;
                    end
                end

                CAPTURE_W2: begin
                    if (idx < 6'd32) begin
                        if ((char_in[idx] == 8'h50 || char_in[idx] == 8'h70) && w2_idx == 6'd0) begin
                            word2[0] <= char_in[idx];
                            w2_idx <= 6'd1;
                            idx <= idx + 6'd1;
                        end else if (w2_idx > 6'd0 && char_in[idx] != 8'h20) begin
                            if (w2_idx < 6'd8) begin
                                word2[w2_idx] <= char_in[idx];
                                w2_idx <= w2_idx + 6'd1;
                            end
                            idx <= idx + 6'd1;
                        end else if (char_in[idx] == 8'h20 && w2_idx > 6'd0) begin
                            state <= FINISHED;
                            found <= 1'b1;
                            done <= 1'b1;
                        end else if (char_in[idx] != 8'h20 && w2_idx == 6'd0) begin
                            state <= FINISHED;
                            found <= 1'b0;
                            done <= 1'b1;
                        end else begin
                            idx <= idx + 6'd1;
                        end
                    end else if (w2_idx > 6'd0) begin
                        state <= FINISHED;
                        found <= 1'b1;
                        done <= 1'b1;
                    end else begin
                        state <= FINISHED;
                        found <= 1'b0;
                        done <= 1'b1;
                    end
                end

                FINISHED: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule