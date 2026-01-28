module pair_wise(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    input [3:0] len,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] DONE    = 2'd2;

    reg [1:0] state;
    reg [2:0] pair_index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            pair_index <= 3'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        if (len > 1) begin
                            state <= PROCESS;
                            pair_index <= 3'd0;
                        end else begin
                            state <= DONE;
                        end
                    end
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    result <= {arr[pair_index + 1], arr[pair_index]};
                    done <= 1'b1;
                    if (pair_index < len - 1 - 1) begin
                        pair_index <= pair_index + 3'd1;
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b0;
                    result <= 16'd0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule