module remove_odd(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire [3:0] str_len,
    output reg [7:0] char_out,
    output reg out_valid,
    output reg done
);

    reg [3:0] state;
    reg [3:0] pos_counter;

    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] PROCESS = 4'd1;
    localparam [3:0] DONE = 4'd2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pos_counter <= 4'd0;
            char_out <= 8'd0;
            out_valid <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PROCESS;
                        pos_counter <= 4'd1;
                        out_valid <= 1'b0;
                        done <= 1'b0;
                    end
                end

                PROCESS: begin
                    if (pos_counter <= str_len) begin
                        if (pos_counter[0] == 1'b0) begin
                            char_out <= char_in;
                            out_valid <= 1'b1;
                        end else begin
                            out_valid <= 1'b0;
                        end
                        pos_counter <= pos_counter + 4'd1;
                    end else begin
                        out_valid <= 1'b0;
                        done <= 1'b1;
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule