module sum_of_squares (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] arr [0:15],
    input wire [3:0] len,
    output reg [15:0] result,
    output reg done
);

// State declarations
localparam [1:0] IDLE    = 2'd0;
localparam [1:0] PROCESS = 2'd1;
localparam [1:0] UPDATE  = 2'd2;
localparam [1:0] FINISH  = 2'd3;

// Registers and counters
reg [1:0] state;
reg [3:0] index;           // 4-bit index (0 to 15)
reg [15:0] temp_result;    // 16-bit accumulator
reg [15:0] square_temp;    // 16-bit square temporary storage
reg [7:0] element;         // Current element storage
reg [7:0] bit_counter;     // Counter for bit-by-bit square calculation
reg square_done;           // Flag for square calculation completion

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 16'd0;
        done <= 1'b0;
        index <= 4'd0;
        temp_result <= 16'd0;
        square_temp <= 16'd0;
        element <= 8'd0;
        bit_counter <= 8'd0;
        square_done <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                index <= 4'd0;
                temp_result <= 16'd0;
                square_temp <= 16'd0;
                bit_counter <= 8'd0;
                square_done <= 1'b0;
                
                if (start) begin
                    if (len == 4'd0) begin
                        state <= FINISH;  // Zero length: go directly to finish
                    end else begin
                        state <= PROCESS;
                    end
                end
            end
            
            PROCESS: begin
                // Read current element
                element <= arr[index];
                
                // Check if positive (>=1) and odd
                // Positive: MSB=0 and not zero (for signed 8-bit, positive means value > 0)
                // For signed integer, positive means value >= 1
                // Check: element > 0 (which means MSB=0 and not zero)
                // But for simplicity, check: (element[7] == 1'b0) && (element != 8'd0)
                // And odd: element[0] == 1'b1
                
                if ((element[7] == 1'b0) && (element != 8'd0) && (element[0] == 1'b1)) begin
                    // Valid odd positive integer
                    square_done <= 1'b0;
                    bit_counter <= 8'd0;
                    square_temp <= 16'd0;
                    
                    // Start sequential multiplication (element * element)
                    // Using bit-by-bit addition for clarity and reliability
                    state <= UPDATE;
                end else begin
                    // Skip invalid element
                    state <= UPDATE;
                    square_done <= 1'b1;
                    square_temp <= 16'd0;
                end
            end
            
            UPDATE: begin
                if (!square_done) begin
                    // Perform sequential multiplication to compute square
                    // element * element using repeated addition
                    if (bit_counter < 8'd8) begin
                        // For each bit in element, add element if bit is 1
                        if (element[bit_counter] == 1'b1) begin
                            // Add element shifted appropriately
                            // This is simplified: we add element to result
                            // For actual multiplication, we need proper bit-weighting
                            // Using this approximation for sequential adder
                            square_temp <= square_temp + ({8'd0, element} << bit_counter);
                        end
                        bit_counter <= bit_counter + 8'd1;
                    end else begin
                        square_done <= 1'b1;
                    end
                end else begin
                    // Square complete (or skipped)
                    // Add to accumulator
                    temp_result <= temp_result + square_temp;
                    
                    // Move to next element
                    index <= index + 4'd1;
                    
                    if (index + 4'd1 >= len) begin
                        state <= FINISH;
                    end else begin
                        state <= PROCESS;
                    end
                end
            end
            
            FINISH: begin
                result <= temp_result;
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule