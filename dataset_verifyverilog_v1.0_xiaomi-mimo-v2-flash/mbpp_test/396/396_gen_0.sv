module StringStartEndCheck (
    input clk,
    input rst_n,
    input start,
    input [7:0] string_data [0:7],
    input [2:0] string_len,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE         = 2'd0;
    localparam [1:0] FETCH_FIRST  = 2'd1;
    localparam [1:0] COMPARE_LAST = 2'd2;
    localparam [1:0] FINISH       = 2'd3;

    reg [1:0] state;
    reg [7:0] first_char;
    reg [7:0] last_char;
    reg [2:0] len_reg;
    reg [4:0] cycle_count;
    localparam [4:0] MAX_CYCLES = 5'd20;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            first_char <= 8'd0;
            last_char <= 8'd0;
            len_reg <= 3'd0;
            cycle_count <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 5'd0;
                    if (start) begin
                        len_reg <= string_len;
                        state <= FETCH_FIRST;
                    end
                end

                FETCH_FIRST: begin
                    cycle_count <= cycle_count + 5'd1;
                    // Check if string is empty (length 0)
                    if (len_reg == 3'd0) begin
                        result <= 1'b0;
                        state <= FINISH;
                    end else begin
                        // Store first character (index 0)
                        first_char <= string_data[0];
                        // For single character, last_char is same as first
                        if (len_reg == 3'd1) begin
                            last_char <= string_data[0];
                            state <= COMPARE_LAST;
                        end else begin
                            state <= COMPARE_LAST;
                        end
                    end
                end

                COMPARE_LAST: begin
                    cycle_count <= cycle_count + 5'd1;
                    // For length > 1, get last character from array
                    if (len_reg > 3'd1) begin
                        case (len_reg)
                            3'd2: last_char <= string_data[1];
                            3'd3: last_char <= string_data[2];
                            3'd4: last_char <= string_data[3];
                            3'd5: last_char <= string_data[4];
                            3'd6: last_char <= string_data[5];
                            3'd7: last_char <= string_data[6];
                            default: last_char <= 8'd0;
                        endcase
                    end
                    // Compare first and last characters
                    if (first_char == last_char) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule