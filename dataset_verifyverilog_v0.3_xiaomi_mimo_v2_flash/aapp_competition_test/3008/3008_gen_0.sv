module findmax(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] a,
    input wire [15:0] b,
    input wire [15:0] c,
    input wire [15:0] d,
    input wire [15:0] e,
    input wire [15:0] f,
    input wire [15:0] g,
    input wire [15:0] h,
    output reg [15:0] max_val,
    output reg [3:0] max_index,
    output reg done
);

// State machine definitions
localparam [1:0] IDLE = 2'd0;
localparam [1:0] LOAD = 2'd1;
localparam [1:0] COMPARE = 2'd2;
localparam [1:0] FINISH = 2'd3;

reg [1:0] state, next_state;

// Internal registers
reg [15:0] data_reg [0:7];  // 8 elements, 16 bits each
reg [3:0] idx;               // Current index for comparison
reg [15:0] current_max;
reg [3:0] current_idx;

// Helper variables for array iteration
integer i;

// State transition and sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        max_val <= 16'd0;
        max_index <= 4'd0;
        done <= 1'b0;
        idx <= 4'd0;
        current_max <= 16'd0;
        current_idx <= 4'd0;
        // Initialize all array elements
        for (i = 0; i < 8; i = i + 1) begin
            data_reg[i] <= 16'd0;
        end
    end else begin
        state <= next_state;
        
        case (state)
            IDLE: begin
                done <= 1'b0;
                idx <= 4'd0;
                if (start) begin
                    // Load data into registers
                    data_reg[0] <= a;
                    data_reg[1] <= b;
                    data_reg[2] <= c;
                    data_reg[3] <= d;
                    data_reg[4] <= e;
                    data_reg[5] <= f;
                    data_reg[6] <= g;
                    data_reg[7] <= h;
                    current_max <= a;  // Initialize with first element
                    current_idx <= 4'd0;
                end
            end
            
            LOAD: begin
                // Ensure data is loaded (state transition)
                idx <= 4'd1;
            end
            
            COMPARE: begin
                if (idx < 4'd8) begin
                    // Compare current element with current_max
                    if (data_reg[idx] > current_max) begin
                        current_max <= data_reg[idx];
                        current_idx <= idx;
                    end
                    idx <= idx + 4'd1;
                end
            end
            
            FINISH: begin
                max_val <= current_max;
                max_index <= current_idx;
                done <= 1'b1;
            end
            
            default: begin
                state <= IDLE;
                done <= 1'b0;
            end
        endcase
    end
end

// Next state logic
always @(*) begin
    next_state = state;
    
    case (state)
        IDLE: begin
            if (start) next_state = LOAD;
            else next_state = IDLE;
        end
        
        LOAD: begin
            next_state = COMPARE;
        end
        
        COMPARE: begin
            if (idx >= 4'd8) next_state = FINISH;
            else next_state = COMPARE;
        end
        
        FINISH: begin
            if (!start) next_state = IDLE;
            else next_state = FINISH;
        end
        
        default: next_state = IDLE;
    endcase
end

endmodule