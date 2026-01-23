module ReplaceSpaces(
    input clk,
    input rst_n,
    input start,
    input [7:0] str_in [0:15],
    input [7:0] char_in,
    input [4:0] str_len,
    output reg [7:0] str_out [0:15],
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    reg [1:0] state;
    reg [3:0] index;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            index <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                str_out[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 4'd0;
                    if (start) begin
                        state <= PROCESS;
                    end
                end

                PROCESS: begin
                    if (index < str_len) begin
                        if (str_in[index] == 8'd32) begin
                            str_out[index] <= char_in;
                        end else begin
                            str_out[index] <= str_in[index];
                        end
                        index <= index + 4'd1;
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule