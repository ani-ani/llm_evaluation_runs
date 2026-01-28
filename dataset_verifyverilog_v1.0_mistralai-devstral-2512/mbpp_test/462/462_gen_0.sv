module CombinationGenerator(
    input clk,
    input rst_n,
    input start,
    input [3:0] len,
    input [7:0] elements_in [0:3],
    output reg [7:0] result [0:3],
    output reg [3:0] result_len,
    output reg valid,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] SAMPLE    = 2'd1;
    localparam [1:0] COUNTING  = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state, next_state;
    reg [3:0] counter;
    reg [3:0] max_count;
    reg [7:0] elements [0:3];
    reg [3:0] current_len;
    reg [3:0] i;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            counter <= 4'd0;
            max_count <= 4'd0;
            result_len <= 4'd0;
            valid <= 1'b0;
            done <= 1'b0;
            for (i = 0; i < 4; i = i + 1) begin
                elements[i] <= 8'd0;
                result[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        next_state <= SAMPLE;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                SAMPLE: begin
                    valid <= 1'b0;
                    done <= 1'b0;
                    current_len <= len;
                    max_count <= (1 << len) - 1;
                    for (i = 0; i < 4; i = i + 1) begin
                        if (i < len) begin
                            elements[i] <= elements_in[i];
                        end else begin
                            elements[i] <= 8'd0;
                        end
                    end
                    next_state <= COUNTING;
                end

                COUNTING: begin
                    valid <= 1'b1;
                    done <= 1'b0;
                    result_len <= 4'd0;
                    for (i = 0; i < 4; i = i + 1) begin
                        result[i] <= 8'd0;
                    end
                    for (i = 0; i < 4; i = i + 1) begin
                        if (counter[i] && i < current_len) begin
                            result[result_len] <= elements[i];
                            result_len <= result_len + 1;
                        end
                    end
                    if (counter == max_count) begin
                        next_state <= DONE_STATE;
                    end else begin
                        counter <= counter + 1;
                        next_state <= COUNTING;
                    end
                end

                DONE_STATE: begin
                    valid <= 1'b0;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end
endmodule