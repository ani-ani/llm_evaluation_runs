module string_sequence(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg [7:0] byte_out,
    output reg valid,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE         = 2'd0;
    localparam [1:0] GENERATE_NUM = 2'd1;
    localparam [1:0] OUTPUT_SPACE = 2'd2;
    localparam [1:0] FINISHED     = 2'd3;

    reg [1:0] state, next_state;
    reg [3:0] current_num;
    reg [7:0] char_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_num <= 4'd0;
            char_count <= 8'd0;
            byte_out <= 8'd0;
            valid <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        current_num <= 4'd0;
                        char_count <= 8'd0;
                        next_state <= GENERATE_NUM;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                GENERATE_NUM: begin
                    valid <= 1'b1;
                    byte_out <= 8'd48 + current_num;  // ASCII '0' + number
                    if (current_num == n) begin
                        next_state <= FINISHED;
                    end else begin
                        next_state <= OUTPUT_SPACE;
                    end
                end

                OUTPUT_SPACE: begin
                    valid <= 1'b1;
                    byte_out <= 8'd32;  // ASCII space
                    current_num <= current_num + 4'd1;
                    next_state <= GENERATE_NUM;
                end

                FINISHED: begin
                    done <= 1'b1;
                    valid <= 1'b0;
                    next_state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    valid <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule