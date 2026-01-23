module coin_optimizer (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] P,
    input wire [7:0] N1,
    input wire [7:0] N5,
    input wire [7:0] N10,
    input wire [7:0] N25,
    output reg [7:0] result,
    output reg valid,
    output reg done
);
    // State encoding
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] CHECK_X25     = 4'd1;
    localparam [3:0] CHECK_X10     = 4'd2;
    localparam [3:0] CHECK_X5      = 4'd3;
    localparam [3:0] INCR_X10      = 4'd4;
    localparam [3:0] INCR_X25      = 4'd5;
    localparam [3:0] DONE          = 4'd6;

    reg [3:0] state, next_state;
    reg [3:0] x25;
    reg [4:0] x10;
    reg [5:0] x5;
    reg [7:0] max_coins;
    reg found;
    reg [7:0] x1;
    wire [15:0] val25 = x25 * 8'd25;
    wire [15:0] val10 = x10 * 8'd10;
    wire [15:0] val5  = x5 * 8'd5;
    wire [15:0] total = val25 + val10 + val5;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'b0;
            valid <= 1'b0;
            done <= 1'b0;
            x25 <= 4'b0;
            x10 <= 5'b0;
            x5 <= 6'b0;
            max_coins <= 8'b0;
            found <= 1'b0;
            x1 <= 8'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        x25 <= 4'b0;
                        x10 <= 5'b0;
                        x5 <= 6'b0;
                        max_coins <= 8'b0;
                        found <= 1'b0;
                        state <= CHECK_X25;
                    end
                end

                CHECK_X25: begin
                    if (x25 <= N25 && val25 <= P) begin
                        x10 <= 5'b0;
                        state <= CHECK_X10;
                    end else begin
                        state <= DONE;
                    end
                end

                CHECK_X10: begin
                    if (x10 <= N10 && (val25 + val10) <= P) begin
                        x5 <= 6'b0;
                        state <= CHECK_X5;
                    end else begin
                        if (x10 < N10) begin
                            x10 <= x10 + 5'd1;
                            state <= CHECK_X10;
                        end else begin
                            x25 <= x25 + 4'd1;
                            state <= CHECK_X25;
                        end
                    end
                end

                CHECK_X5: begin
                    if (x5 <= N5 && total <= P) begin
                        x1 <= P - total[7:0];
                        if (x1 <= N1) begin
                            if (x1 + x5[7:0] + x10[7:0] + x25[7:0] > max_coins) begin
                                max_coins <= x1 + x5[7:0] + x10[7:0] + x25[7:0];
                                found <= 1'b1;
                            end
                        end
                        if (x5 < N5) begin
                            x5 <= x5 + 6'd1;
                            state <= CHECK_X5;
                        end else begin
                            state <= INCR_X10;
                        end
                    end else begin
                        state <= INCR_X10;
                    end
                end

                INCR_X10: begin
                    if (x10 < N10) begin
                        x10 <= x10 + 5'd1;
                        state <= CHECK_X10;
                    end else begin
                        state <= INCR_X25;
                    end
                end

                INCR_X25: begin
                    x25 <= x25 + 4'd1;
                    state <= CHECK_X25;
                end

                DONE: begin
                    result <= max_coins;
                    valid <= found;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule