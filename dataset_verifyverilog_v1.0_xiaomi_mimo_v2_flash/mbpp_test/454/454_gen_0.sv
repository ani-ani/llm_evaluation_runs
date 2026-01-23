module text_match_wordz(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_array [0:15],
    input wire [4:0] str_len,
    output reg result,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SCANNING = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;

    reg [1:0] state;
    reg [4:0] index;
    reg found_z;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 5'd0;
            found_z <= 1'b0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= SCANNING;
                        index <= 5'd0;
                        found_z <= 1'b0;
                    end
                end

                SCANNING: begin
                    if (index < str_len) begin
                        if (char_array[index] == 8'h7A) begin
                            found_z <= 1'b1;
                        end
                        index <= index + 5'd1;
                    end else begin
                        state <= COMPLETE;
                        result <= found_z;
                        done <= 1'b1;
                    end
                end

                COMPLETE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule