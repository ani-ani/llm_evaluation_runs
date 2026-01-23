module curfew_enforcement (
    input clk,
    input rst_n,
    input start,
    input [4:0] n,        // Number of rooms (max 16)
    input [3:0] d,        // Maximum movement distance (max 15)
    input [7:0] b,        // Target students per room (max 255)
    input [7:0] a [0:15], // Initial students per room (8-bit each)
    output reg [7:0] result, // Result: minimal max(x1, x2)
    output reg done        // Completion signal
);

// Parameters for scaling
parameter MAX_ROOMS = 16;
parameter DATA_WIDTH = 8;
parameter ADDR_WIDTH = 4;

// State machine states
reg [3:0] state;
localparam IDLE = 0;
localparam COMPUTE_PREFIX = 1;
localparam COMPUTE_X = 2;
localparam UPDATE_RESULT = 3;
localparam FINISHED = 4;

// Registers
reg [15:0] prefix [0:16];  // Prefix sums, 16-bit to handle large totals
reg [15:0] total_students;
reg [7:0] current_result;
reg [4:0] i;               // Loop counter for rooms
reg [4:0] half_n;          // (n+1)//2
reg [7:0] left_index, right_index;
reg [15:0] available_left, available_right, available;
reg [7:0] rooms_filled;
reg [7:0] x_i;
reg [7:0] max_x;

integer j;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 0;
        result <= 0;
        current_result <= 0;
        max_x <= 0;
        i <= 0;
        total_students <= 0;
        for (j = 0; j <= 16; j = j + 1) begin
            prefix[j] <= 0;
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 0;
                if (start) begin
                    state <= COMPUTE_PREFIX;
                    i <= 0;
                    total_students <= 0;
                    prefix[0] <= 0;
                end
            end
            
            COMPUTE_PREFIX: begin
                // Compute prefix sums: prefix[i] = sum(a[0:i-1])
                if (i < n) begin
                    total_students <= total_students + a[i];
                    prefix[i+1] <= total_students + a[i];
                    i <= i + 1;
                end else begin
                    i <= 1;  // Start from i=1
                    max_x <= 0;
                    state <= COMPUTE_X;
                end
            end
            
            COMPUTE_X: begin
                // Compute x_i = i - min(prefix[min(n, i*d)], (total_students - prefix[max(0, n-i*d)])) / b
                half_n = (n + 1) >> 1;
                
                if (i <= half_n) begin
                    // left_index = min(n, i*d)
                    if (i * d < n)
                        left_index = i * d;
                    else
                        left_index = n;
                    
                    // right_index = max(0, n - i*d)
                    if (n > i * d)
                        right_index = n - i * d;
                    else
                        right_index = 0;
                    
                    // available_left = prefix[left_index]
                    available_left = prefix[left_index];
                    
                    // available_right = total_students - prefix[right_index]
                    available_right = total_students - prefix[right_index];
                    
                    // available = min(available_left, available_right)
                    if (available_left < available_right)
                        available = available_left;
                    else
                        available = available_right;
                    
                    // rooms_filled = available / b (integer division)
                    rooms_filled = available / b;
                    
                    // x_i = i - rooms_filled
                    if (i > rooms_filled)
                        x_i = i - rooms_filled;
                    else
                        x_i = 0;
                    
                    state <= UPDATE_RESULT;
                end else begin
                    state <= FINISHED;
                end
            end
            
            UPDATE_RESULT: begin
                // Update max_x
                if (x_i > max_x)
                    max_x <= x_i;
                
                i <= i + 1;
                state <= COMPUTE_X;
            end
            
            FINISHED: begin
                result <= max_x;
                done <= 1;
                state <= IDLE;
            end
        endcase
    end
end

endmodule