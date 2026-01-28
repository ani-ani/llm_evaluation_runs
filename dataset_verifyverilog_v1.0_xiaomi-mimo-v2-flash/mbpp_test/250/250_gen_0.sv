module CountOccurrences(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:11],
    input [7:0] target,
    input [3:0] len,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COUNTING = 2'd1;
    localparam [1:0] DONE = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [3:0] index;
    reg [15:0] count;
    reg [15:0] result_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            count <= 16'd0;
            result_reg <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COUNTING;
                        index <= 4'd0;
                        count <= 16'd0;
                    end
                end

                COUNTING: begin
                    // Compare current element with target
                    if (arr[index] == target) begin
                        count <= count + 16'd1;
                    end
                    
                    // Check if we've processed all elements
                    if (index == (len - 4'd1)) begin
                        state <= DONE;
                        result_reg <= (arr[index] == target) ? (count + 16'd1) : count;
                    end else begin
                        index <= index + 4'd1;
                    end
                end

                DONE: begin
                    result <= result_reg;
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