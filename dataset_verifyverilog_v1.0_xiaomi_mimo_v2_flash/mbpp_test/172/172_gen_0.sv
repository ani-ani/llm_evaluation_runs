module string_pattern_matcher (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire [3:0] str_len,
    output reg [7:0] count,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD = 2'd1;
    localparam [1:0] CHECK = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    localparam [7:0] CHAR_S = 8'h73;
    localparam [7:0] CHAR_T = 8'h74;
    localparam [7:0] CHAR_D = 8'h64;

    reg [1:0] state, next_state;
    reg [3:0] idx;
    reg [7:0] window0, window1, window2;
    reg [7:0] cnt_reg;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd15;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx <= 4'd0;
            window0 <= 8'd0;
            window1 <= 8'd0;
            window2 <= 8'd0;
            cnt_reg <= 8'd0;
            count <= 8'd0;
            done <= 1'b0;
            cycle_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        state <= LOAD;
                        idx <= 4'd0;
                        cnt_reg <= 8'd0;
                        window0 <= 8'd0;
                        window1 <= 8'd0;
                        window2 <= 8'd0;
                    end
                end

                LOAD: begin
                    cycle_count <= cycle_count + 4'd1;
                    if (idx < str_len) begin
                        window0 <= window1;
                        window1 <= window2;
                        window2 <= char_in;
                        idx <= idx + 4'd1;
                        if (idx >= 4'd2) begin
                            state <= CHECK;
                        end
                    end else begin
                        state <= FINISH;
                    end
                end

                CHECK: begin
                    cycle_count <= cycle_count + 4'd1;
                    if (window0 == CHAR_S && window1 == CHAR_T && window2 == CHAR_D) begin
                        cnt_reg <= cnt_reg + 8'd1;
                    end
                    state <= LOAD;
                end

                FINISH: begin
                    done <= 1'b1;
                    count <= cnt_reg;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule