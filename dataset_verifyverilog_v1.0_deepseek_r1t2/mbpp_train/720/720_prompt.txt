module tuple_dict_appender (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] tuple_data [0:3],  // 4-element tuple, each 32-bit
    input wire [31:0] dict_data,          // Packed dictionary (3x key-value pairs)
    output reg [31:0] result [0:4],       // 5-element result tuple
    output reg done
);

// This module appends a dictionary value to a tuple
// Input tuple: 4 elements of 32-bit each (indices 0-3)
// Input dict: 32-bit packed value representing dictionary
// Output tuple: 5 elements, where result[4] = dict_data
// Timing: Assert start for 1 cycle, done goes high after 2 cycles

integer i;
reg [1:0] state;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset: clear all outputs
        for (i = 0; i < 5; i = i + 1) begin
            result[i] <= 32'b0;
        end
        done <= 1'b0;
        state <= 2'b00;
    end else begin
        case (state)
            2'b00: begin  // Idle state
                done <= 1'b0;
                if (start) begin
                    state <= 2'b01;
                end
            end
            
            2'b01: begin  // Copy first 4 elements from tuple
                for (i = 0; i < 4; i = i + 1) begin
                    result[i] <= tuple_data[i];
                end
                state <= 2'b10;
            end
            
            2'b10: begin  // Append dictionary as 5th element
                result[4] <= dict_data;
                done <= 1'b1;
                state <= 2'b11;
            end
            
            2'b11: begin  // Wait for start to go low
                done <= 1'b0;
                if (!start) begin
                    state <= 2'b00;
                end
            end
        endcase
    end
end

endmodule