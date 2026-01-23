module can_arrange(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    input [2:0] len,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] DONE    = 2'd2;

    reg [1:0] state;
    reg [7:0] result_reg;
    reg [2:0] index;
    reg [7:0] last_index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_reg <= 8'd0;
            done <= 1'b0;
            index <= 3'd0;
            last_index <= 8'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPARE;
                        index <= 3'd1;
                        last_index <= 8'd0;
                    end
                end

                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (index < len) begin
                        if (arr[index] < arr[index - 1]) begin
                            last_index <= index + 8'd1;
                        end
                        index <= index + 3'd1;
                    end else begin
                        if (last_index == 8'd0) begin
                            result_reg <= 8'd255; // -1 in 8-bit signed
                        end else begin
                            result_reg <= last_index;
                        end
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    result <= result_reg;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule