module array_comparator(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr1 [0:7],
    input [7:0] arr2 [0:7],
    input [3:0] len,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    reg [1:0] state;
    reg [2:0] index;
    reg fail;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 3'd0;
            fail <= 1'b0;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPARE;
                        index <= 3'd0;
                        fail <= 1'b0;
                    end
                end

                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compare current element
                    if (arr1[index] <= arr2[index]) begin
                        fail <= 1'b1;
                    end
                    
                    // Move to next element or finish
                    if (index == len - 1 || fail || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        index <= index + 3'd1;
                    end
                end

                FINISH: begin
                    result <= ~fail;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule