module pattern_detector(
    input clk,
    input rst_n,
    input start,
    input [7:0] input_str [0:15],
    input [3:0] str_len,
    output reg found,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] PROCESS   = 3'd1;
    localparam [2:0] CHECK     = 3'd2;
    localparam [2:0] COMPLETE  = 3'd3;

    reg [2:0] state, next_state;
    reg [3:0] index;
    reg [3:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            index <= 4'd0;
            found <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    found <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= PROCESS;
                        index <= 4'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (index < str_len - 3'd3) begin
                        if (input_str[index] == 8'h61) begin
                            next_state <= CHECK;
                        end else begin
                            index <= index + 4'd1;
                            next_state <= PROCESS;
                        end
                    end else begin
                        next_state <= COMPLETE;
                    end
                end

                CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    if ((input_str[index + 4'd1] == 8'h62) &&
                        (input_str[index + 4'd2] == 8'h62) &&
                        (input_str[index + 4'd3] == 8'h62)) begin
                        found <= 1'b1;
                    end
                    index <= index + 4'd1;
                    next_state <= PROCESS;
                end

                COMPLETE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    found <= 1'b0;
                end
            endcase
        end
    end
endmodule