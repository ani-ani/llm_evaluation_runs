module remove_odd (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7,
    input wire [3:0] len,
    output reg [7:0] out_0, out_1, out_2, out_3, out_4, out_5, out_6, out_7,
    output reg [3:0] out_len,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;

    reg [1:0] state;
    reg [3:0] idx;
    reg [3:0] write_idx;
    reg [7:0] buffer [0:7];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx <= 4'd0;
            write_idx <= 4'd0;
            out_len <= 4'd0;
            done <= 1'b0;
            out_0 <= 8'd0; out_1 <= 8'd0; out_2 <= 8'd0; out_3 <= 8'd0;
            out_4 <= 8'd0; out_5 <= 8'd0; out_6 <= 8'd0; out_7 <= 8'd0;
            buffer[0] <= 8'd0; buffer[1] <= 8'd0; buffer[2] <= 8'd0; buffer[3] <= 8'd0;
            buffer[4] <= 8'd0; buffer[5] <= 8'd0; buffer[6] <= 8'd0; buffer[7] <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        buffer[0] <= arr_0;
                        buffer[1] <= arr_1;
                        buffer[2] <= arr_2;
                        buffer[3] <= arr_3;
                        buffer[4] <= arr_4;
                        buffer[5] <= arr_5;
                        buffer[6] <= arr_6;
                        buffer[7] <= arr_7;
                        idx <= 4'd0;
                        write_idx <= 4'd0;
                        out_len <= 4'd0;
                        state <= PROCESS;
                        out_0 <= 8'd0; out_1 <= 8'd0; out_2 <= 8'd0; out_3 <= 8'd0;
                        out_4 <= 8'd0; out_5 <= 8'd0; out_6 <= 8'd0; out_7 <= 8'd0;
                    end
                end

                PROCESS: begin
                    if (idx < len) begin
                        if (buffer[idx][0] == 1'b0) begin
                            case (write_idx)
                                4'd0: out_0 <= buffer[idx];
                                4'd1: out_1 <= buffer[idx];
                                4'd2: out_2 <= buffer[idx];
                                4'd3: out_3 <= buffer[idx];
                                4'd4: out_4 <= buffer[idx];
                                4'd5: out_5 <= buffer[idx];
                                4'd6: out_6 <= buffer[idx];
                                4'd7: out_7 <= buffer[idx];
                            endcase
                            write_idx <= write_idx + 4'd1;
                        end
                        idx <= idx + 4'd1;
                    end else begin
                        out_len <= write_idx;
                        state <= COMPLETE;
                    end
                end

                COMPLETE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule