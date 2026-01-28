module cinema_seating (
    input clk,
    input rst_n,
    input start,
    input [1:0] n,          // 1 to 3
    input [1:0] c1, c2, c3, // counts for group sizes 1,2,3 (0 to 2)
    output reg [2:0] result, // 1-4 or 5 (impossible)
    output reg done
);

// State declarations
localparam [1:0] IDLE = 2'd0;
localparam [1:0] COMPUTE = 2'd1;
localparam [1:0] FINISH = 2'd2;

reg [1:0] state;
reg [1:0] next_state;

// Always block for sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 3'd0;
        done <= 1'b0;
    end else begin
        state <= next_state;
    end
end

// Combinational logic for next state and outputs
always @(*) begin
    // Default values
    next_state = state;
    result = 5;
    done = 1'b0;
    
    case (state)
        IDLE: begin
            done = 1'b0;
            if (start) begin
                next_state = COMPUTE;
            end
        end
        
        COMPUTE: begin
            // Lookup table for all 39 valid inputs
            // Default: impossible
            result = 5;
            case ({n, c3, c2, c1})
                // n = 1 (2'b01)
                8'b01_00_00_00: result = 1; // no groups
                8'b01_00_00_01: result = 1; // one solo
                8'b01_00_00_02: result = 2; // two solos
                // n = 2 (2'b10)
                8'b10_00_00_00: result = 1;
                8'b10_00_00_01: result = 1;
                8'b10_00_00_02: result = 2;
                8'b10_00_01_00: result = 2;
                8'b10_00_01_01: result = 2;
                8'b10_00_01_02: result = 3;
                8'b10_00_02_00: result = 3;
                8'b10_00_02_01: result = 3;
                8'b10_00_02_02: result = 4;
                // n = 3 (2'b11)
                8'b11_00_00_01: result = 1;
                8'b11_00_00_02: result = 2;
                8'b11_00_01_00: result = 2;
                8'b11_00_01_01: result = 2;
                8'b11_00_01_02: result = 3;
                8'b11_00_02_00: result = 3;
                8'b11_00_02_01: result = 3;
                8'b11_00_02_02: result = 4;
                8'b11_01_00_00: result = 3;
                8'b11_01_00_01: result = 3;
                8'b11_01_00_02: result = 3;
                8'b11_01_01_00: result = 3;
                8'b11_01_01_01: result = 3;
                8'b11_01_01_02: result = 4;
                8'b11_01_02_00: result = 4;
                8'b11_01_02_01: result = 4;
                8'b11_01_02_02: result = 4;
                8'b11_02_00_00: result = 4;
                8'b11_02_00_01: result = 4;
                8'b11_02_00_02: result = 4;
                8'b11_02_01_00: result = 4;
                8'b11_02_01_01: result = 4;
                8'b11_02_01_02: result = 5;
                8'b11_02_02_00: result = 5;
                default: result = 5;
            endcase
            // Override: if n == 0, treat as impossible
            if (n == 2'd0) result = 5;
            
            // Transition to finish state
            next_state = FINISH;
        end
        
        FINISH: begin
            done = 1'b1;
            next_state = IDLE;
        end
        
        default: next_state = IDLE;
    endcase
end

endmodule