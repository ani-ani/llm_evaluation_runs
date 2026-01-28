module unique_element_finder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    input wire [3:0] len,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] PROCESS  = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;

    // Internal signals
    reg [1:0] state;
    reg [3:0] index;
    reg [15:0] accumulator;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            accumulator <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESS;
                        index <= 4'd0;
                        accumulator <= 16'd0;
                    end
                end

                PROCESS: begin
                    // XOR current element with accumulator
                    accumulator <= accumulator ^ {8'd0, arr[index]};
                    
                    // Move to next element
                    index <= index + 4'd1;
                    
                    // Check if all elements processed
                    if (index == len) begin
                        state <= COMPLETE;
                    end
                end

                COMPLETE: begin
                    result <= accumulator;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule