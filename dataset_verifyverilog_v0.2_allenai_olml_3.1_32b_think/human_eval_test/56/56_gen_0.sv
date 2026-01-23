module bracket_validator (
    input clk,
    input rst_n, // Active-low reset
    input start,
    input [127:0] brackets,
    input [4:0] length,
    output reg valid,
    output reg done
);

reg [3:0] counter;
reg [3:0] index;
reg [1:0] state;
// reg [7:0] temp; // not needed

initial begin
    counter <=0;
    index <=0;
    state <= 2'b00;
    valid <=1'b1;
    done <=1'b0;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        counter <=0;
        index <=0;
        state <= 2'b00;
        valid <=1'b1;
        done <=1'b0;
    end else begin
        case (state)
            2'b00: begin
                if (start) begin
                    if (length ==0) begin
                        done <=1'b1;
                        valid <=1'b1;
                        state <= 2'b10;
                    end else begin
                        counter <=0;
                        index <=0;
                        valid <=1'b1;
                        state <= 2'b01;
                    end
                end
                done <=1'b0;
            end
            2'b01: begin
                if (index < length) begin
                    // Extract current_char
                    reg [7:0] current_char;
                    case (index)
                        0: current_char = brackets >> 120 & 8'hFF;
                        1: current_char = brackets >> 112 & 8'hFF;
                        2: current_char = brackets >> 104 & 8'hFF;
                        3: current_char = brackets >> 96 & 8'hFF;
                        4: current_char = brackets >> 88 & 8'hFF;
                        5: current_char = brackets >> 80 & 8'hFF;
                        6: current_char = brackets >> 72 & 8'hFF;
                        7: current_char = brackets >> 64 & 8'hFF;
                        8: current_char = brackets >> 56 & 8'hFF;
                        9: current_char = brackets >> 48 & 8'hFF;
                        10: current_char = brackets >> 40 & 8'hFF;
                        11: current_char = brackets >> 32 & 8'hFF;
                        12: current_char = brackets >> 24 & 8'hFF;
                        13: current_char = brackets >> 16 & 8'hFF;
                        14: current_char = brackets >> 8 & 8'hFF;
                        15: current_char = brackets >> 0 & 8'hFF;
                    endcase

                    if (current_char == 8'<' ) begin
                        counter <= counter + 1;
                    end else if (current_char == 8'>' ) begin
                        if (counter == 0) begin
                            valid <= 1'b0;
                        end
                        counter <= counter - 1;
                    end // else ignore

                    index <= index + 1;

                    if (index == length) begin
                        valid <= valid && (counter == 0);
                        done <= 1'b1;
                        state <= 2'b10;
                    end
                end else begin
                    // This should not happen if index is properly incremented
                    done <= 1'b1;
                    valid <= valid && (counter == 0);
                    state <= 2'b10;
                end
            end
            2'b10: begin
                // Stay in DONE, outputs are already set
                done <= done;
                valid <= valid;
            end
            default: state <= state;
        endcase
    end
endmodule