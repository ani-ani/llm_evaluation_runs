module find_min #(
    parameter ARRAY_SIZE = 8,
    parameter DATA_WIDTH = 8,
    parameter RESULT_WIDTH = 8
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] arr [0:ARRAY_SIZE-1],
    input wire [3:0] len,
    output reg [RESULT_WIDTH-1:0] result,
    output reg done
);

// State machine states
reg [2:0] state;
reg [2:0] next_state;
localparam [2:0] IDLE = 3'd0;
localparam [2:0] COMPARE = 3'd1;
localparam [2:0] FINISHED = 3'd2;

// Internal registers
reg [DATA_WIDTH-1:0] current_min;
reg [3:0] index;
reg [3:0] cycle_counter;
localparam [3:0] MAX_CYCLES = 4'd10;

// State register
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 8'd0;
        done <= 1'b0;
        current_min <= 8'd0;
        index <= 4'd0;
        cycle_counter <= 4'd0;
    end else begin
        state <= next_state;
    end
end

// Next state and output logic
always @(*) begin
    // Defaults
    next_state = state;
    result = result;
    done = 1'b0;
    current_min = current_min;
    index = index;
    cycle_counter = cycle_counter;
    
    case (state)
        IDLE: begin
            done = 1'b0;
            cycle_counter = 4'd0;
            if (start && len > 4'd0) begin
                current_min = arr[0];
                index = 4'd1;
                next_state = COMPARE;
            end
        end
        
        COMPARE: begin
            if (index < len && cycle_counter < MAX_CYCLES) begin
                if (arr[index] < current_min) begin
                    current_min = arr[index];
                end
                index = index + 4'd1;
                cycle_counter = cycle_counter + 4'd1;
            end else begin
                result = current_min;
                next_state = FINISHED;
            end
        end
        
        FINISHED: begin
            done = 1'b1;
            next_state = IDLE;
        end
        
        default: begin
            next_state = IDLE;
        end
    endcase
end

endmodule