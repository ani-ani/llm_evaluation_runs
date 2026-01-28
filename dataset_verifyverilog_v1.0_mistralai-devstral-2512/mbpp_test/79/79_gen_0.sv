module word_length_checker(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] IN_WORD = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    reg [1:0] state;
    reg [3:0] length_counter;
    reg word_active;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            length_counter <= 4'd0;
            word_active <= 1'b0;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= IN_WORD;
                        word_active <= 1'b1;
                        length_counter <= 4'd0;
                    end
                end

                IN_WORD: begin
                    cycle_count <= cycle_count + 8'd1;

                    if (char_in == 8'd0) begin
                        // Null terminator detected
                        result <= (length_counter[0] == 1'b1);
                        state <= FINISH;
                        word_active <= 1'b0;
                    end else if (word_active) begin
                        if (char_in == 8'h20) begin
                            // Space detected - end of first word
                            word_active <= 1'b0;
                        end else begin
                            // Count character in first word
                            if (length_counter < 4'd16) begin
                                length_counter <= length_counter + 4'd1;
                            end
                        end
                    end

                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                        result <= 1'b0;
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