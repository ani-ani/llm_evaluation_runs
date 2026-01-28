module find_min #(
    parameter ARRAY_SIZE = 8,
    parameter DATA_WIDTH = 8,
    parameter RESULT_WIDTH = 8
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] arr [0:ARRAY_SIZE-1],
    input wire [3:0] len,  // Number of valid elements (1-8)
    output reg [RESULT_WIDTH-1:0] result,
    output reg done
);

// State machine states
reg [2:0] state;
localparam IDLE = 3'b000;
localparam COMPARE = 3'b001;
localparam FINISHED = 3'b010;

// Internal registers
reg [DATA_WIDTH-1:0] current_min;
reg [3:0] index;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset state
        state <= IDLE;
        result <= 0;
        done <= 0;
        current_min <= 0;
        index <= 0;
    end else begin
        case (state)
            IDLE: begin
                done <= 0;
                if (start && len > 0) begin
                    // Initialize with first element
                    current_min <= arr[0];
                    index <= 1;  // Start comparing from element 1
                    state <= COMPARE;
                end
            end
            
            COMPARE: begin
                if (index < len) begin
                    // Compare current element with running minimum
                    if (arr[index] < current_min) begin
                        current_min <= arr[index];
                    end
                    index <= index + 1;
                end else begin
                    // All elements processed
                    result <= current_min;
                    state <= FINISHED;
                end
            end
            
            FINISHED: begin
                done <= 1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule