module beautiful_number (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,              // number of digits (1-16)
    input [3:0] k,              // pattern length (1-8)
    input [3:0] digits [0:15],  // input digits (each 0-9)
    output reg [3:0] m,         // output digit count
    output reg [3:0] y_digits [0:15], // output digits
    output reg done
);

// State encoding
localparam [2:0] IDLE = 3'd0;
localparam [2:0] INIT = 3'd1;
localparam [2:0] COMPARE = 3'd2;
localparam [2:0] INCREMENT = 3'd3;
localparam [2:0] OUTPUT = 3'd4;
localparam [2:0] DONE_STATE = 3'd5;

reg [2:0] state;
reg [2:0] next_state;

reg [3:0] pattern [0:7];      // First k digits (pattern)
reg [3:0] i;                  // Counter for loop
reg [1:0] cmp_flag;           // 0: equal, 1: pattern < input, 2: pattern > input
reg [3:0] pattern_digit;      // Current pattern digit for comparison
reg [3:0] input_digit;        // Current input digit for comparison
reg carry;                    // Carry for increment
reg [3:0] j;                  // Secondary counter

// Sequential state transition and output logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        m <= 4'd0;
        i <= 4'd0;
        j <= 4'd0;
        carry <= 1'b0;
        cmp_flag <= 2'd0;
        pattern_digit <= 4'd0;
        input_digit <= 4'd0;
        // Initialize y_digits array
        for (j = 0; j < 16; j = j + 1) begin
            y_digits[j] <= 4'd0;
        end
        // Initialize pattern array
        for (j = 0; j < 8; j = j + 1) begin
            pattern[j] <= 4'd0;
        end
    end else begin
        state <= next_state;
        
        case (state)
            IDLE: begin
                if (start) begin
                    // Initialize pattern buffer from input
                    for (j = 0; j < 8; j = j + 1) begin
                        if (j < k) begin
                            pattern[j] <= digits[j];
                        end else begin
                            pattern[j] <= 4'd0;
                        end
                    end
                    cmp_flag <= 2'd0;
                    done <= 1'b0;
                end
            end
            
            COMPARE: begin
                // Get digits for comparison
                if (i < k) begin
                    pattern_digit <= pattern[i];
                end else begin
                    pattern_digit <= pattern[i - k];
                end
                input_digit <= digits[i];
                
                // Update comparison flag
                if (cmp_flag == 2'd0) begin
                    if (digits[i] > pattern_digit) begin
                        cmp_flag <= 2'd1;  // Pattern < input
                    end else if (digits[i] < pattern_digit) begin
                        cmp_flag <= 2'd2;  // Pattern > input
                    end
                end
            end
            
            INCREMENT: begin
                // Increment the pattern at position i
                if (i < 8) begin
                    if (pattern[i] + carry >= 10) begin
                        pattern[i] <= pattern[i] + carry - 10;
                        carry <= 1'b1;
                    end else begin
                        pattern[i] <= pattern[i] + carry;
                        carry <= 1'b0;
                    end
                end
            end
            
            OUTPUT: begin
                // Generate output by repeating pattern
                m <= n;
                for (j = 0; j < 16; j = j + 1) begin
                    if (j < n) begin
                        if (j < k) begin
                            y_digits[j] <= pattern[j];
                        end else begin
                            y_digits[j] <= pattern[j - k];
                        end
                    end else begin
                        y_digits[j] <= 4'd0;
                    end
                end
            end
            
            DONE_STATE: begin
                done <= 1'b1;
            end
        endcase
    end
end

// Combinational next state logic
always @(*) begin
    next_state = state; // Default to stay in current state
    
    case (state)
        IDLE: begin
            if (start) begin
                next_state = INIT;
            end
        end
        
        INIT: begin
            // Set up for comparison starting at index 0
            next_state = COMPARE;
        end
        
        COMPARE: begin
            // Check if we've compared all digits
            if (i >= n) begin
                // Finished comparison
                if (cmp_flag == 2'd1) begin
                    // Pattern < input, need to increment pattern
                    next_state = INCREMENT;
                end else begin
                    // Pattern >= input, can output directly
                    next_state = OUTPUT;
                end
            end else begin
                // Continue comparing
                next_state = COMPARE;
            end
        end
        
        INCREMENT: begin
            // Handle increment logic
            if (carry == 1'b0) begin
                // Increment complete
                next_state = OUTPUT;
            end else if (i == 0) begin
                // Overflow case - 999...9 + 1 = 1000...0
                // Output will be 1 followed by k-1 zeros (then repeated)
                next_state = OUTPUT;
            end else begin
                // Continue incrementing to next position
                next_state = INCREMENT;
            end
        end
        
        OUTPUT: begin
            // Output state - go to done
            next_state = DONE_STATE;
        end
        
        DONE_STATE: begin
            // Return to idle
            next_state = IDLE;
        end
        
        default: begin
            next_state = IDLE;
        end
    endcase
end

// Counter control logic (combinational)
always @(*) begin
    // Default values
    i = i;
    j = j;
    
    case (state)
        IDLE: begin
            i = 4'd0;
            j = 4'd0;
        end
        
        INIT: begin
            i = 4'd0;
        end
        
        COMPARE: begin
            // Increment counter after each comparison
            if (i < n) begin
                i = i + 4'd1;
            end else begin
                i = i;
            end
        end
        
        INCREMENT: begin
            if (carry == 1'b1) begin
                i = i - 4'd1;
            end else begin
                i = i;
            end
        end
        
        OUTPUT: begin
            i = i;
            j = j;
        end
        
        default: begin
            i = 4'd0;
            j = 4'd0;
        end
    endcase
end

endmodule