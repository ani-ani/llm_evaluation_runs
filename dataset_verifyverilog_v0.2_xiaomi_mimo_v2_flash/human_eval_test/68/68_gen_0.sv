module pluck_module(
    input clk,
    input rst_n,
    input start,
    input [15:0] arr_in,
    input [3:0] arr_index,
    input valid_in,
    input last_in,
    output reg [31:0] result,
    output reg done,
    output reg ready
);

    localparam IDLE = 2'b00;
    localparam COLLECT = 2'b01;
    localparam FINALIZE = 2'b10;
    localparam DONE = 2'b11;

    reg [1:0] state;
    reg [15:0] smallest_value;
    reg [3:0] smallest_index;
    reg found;
    reg capture_last;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'b0;
            done <= 1'b0;
            ready <= 1'b0;
            smallest_value <= 16'hFFFF;
            smallest_index <= 4'b0;
            found <= 1'b0;
            capture_last <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    ready <= 1'b0;
                    capture_last <= 1'b0;
                    if (start) begin
                        state <= COLLECT;
                        ready <= 1'b1;
                        smallest_value <= 16'hFFFF;
                        smallest_index <= 4'b0;
                        found <= 1'b0;
                    end
                end

                COLLECT: begin
                    if (valid_in && ready) begin
                        if (arr_in[0] == 1'b0) begin
                            if (!found || (arr_in < smallest_value) || 
                               (arr_in == smallest_value && arr_index < smallest_index)) begin
                                smallest_value <= arr_in;
                                smallest_index <= arr_index;
                                found <= 1'b1;
                            end
                        end
                    end

                    if (last_in) begin
                        capture_last <= 1'b1;
                    end

                    if (capture_last) begin
                        state <= FINALIZE;
                        ready <= 1'b0;
                        capture_last <= 1'b0;
                    end
                end

                FINALIZE: begin
                    done <= 1'b1;
                    if (found) begin
                        result <= {smallest_index, smallest_value};
                    end else begin
                        result <= 32'b0;
                    end
                    state <= DONE;
                end

                DONE: begin
                    if (start) begin
                        state <= COLLECT;
                        ready <= 1'b1;
                        done <= 1'b0;
                        smallest_value <= 16'hFFFF;
                        smallest_index <= 4'b0;
                        found <= 1'b0;
                    end
                end
            endcase
        end
    end
endmodule