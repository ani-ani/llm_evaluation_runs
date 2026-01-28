module swap_first_last (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    input [3:0] len,
    output reg [7:0] result [0:7],
    output reg done
);

    // State declarations
    localparam [1:0] IDLE  = 2'd0;
    localparam [1:0] SWAP  = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    reg [1:0] state;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd100;
    
    // Array index for swap
    wire [3:0] last_idx;
    assign last_idx = len - 4'd1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 4'd0;
            result[0] <= 8'd0;
            result[1] <= 8'd0;
            result[2] <= 8'd0;
            result[3] <= 8'd0;
            result[4] <= 8'd0;
            result[5] <= 8'd0;
            result[6] <= 8'd0;
            result[7] <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        state <= SWAP;
                    end
                end

                SWAP: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Swap first and last element
                    result[0] <= arr[last_idx];
                    result[last_idx] <= arr[0];
                    
                    // Copy all other elements (non-swapped indices)
                    result[1] <= arr[1];
                    result[2] <= arr[2];
                    result[3] <= arr[3];
                    result[4] <= arr[4];
                    result[5] <= arr[5];
                    result[6] <= arr[6];
                    result[7] <= arr[7];
                    
                    // Exit after 1 cycle (with cycle counter as safety)
                    state <= FINISH;
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