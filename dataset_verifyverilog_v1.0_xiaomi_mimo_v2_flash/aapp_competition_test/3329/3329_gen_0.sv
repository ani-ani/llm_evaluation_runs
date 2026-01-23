module pebble_counter #(
    parameter N = 6,
    parameter MAX_K = 2
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [N-1:0] target,
    input wire [2:0] K,
    output reg [N-1:0] result,
    output reg done
);

// State definitions
localparam [2:0] STATE_IDLE      = 3'd0;
localparam [2:0] STATE_SETUP     = 3'd1;
localparam [2:0] STATE_TRANSFORM = 3'd2;
localparam [2:0] STATE_CHECK     = 3'd3;
localparam [2:0] STATE_ROTATE    = 3'd4;
localparam [2:0] STATE_NEXT      = 3'd5;
localparam [2:0] STATE_DONE      = 3'd6;

// Registers
reg [2:0] state;
reg [2:0] next_state;
reg [N-1:0] candidate;          // Current candidate configuration
reg [N-1:0] transformed;        // Result after K transformations
reg [N-1:0] transformed_next;
reg [N-1:0] temp;               // Temporary for transformation
reg [2:0] k_count;              // Counter for K transformations
reg [2:0] rot_idx;              // Rotation index
reg [5:0] config_counter;       // 0 to 63 for N=6
reg [N-1:0] min_rot;            // Minimum rotation of candidate
reg [N-1:0] temp_rot;           // Temp rotation
reg [N-1:0] original_candidate; // Store original for comparison
reg is_min;                     // Flag if candidate is minimal rotation
reg increment_result;           // Flag to increment result

// State transition logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= STATE_IDLE;
    end else begin
        state <= next_state;
    end
end

// Next state and output logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all registers
        result <= {N{1'b0}};
        done <= 1'b0;
        config_counter <= 6'd0;
        candidate <= {N{1'b0}};
        k_count <= 3'd0;
        rot_idx <= 3'd0;
        min_rot <= {N{1'b0}};
        transformed <= {N{1'b0}};
        temp <= {N{1'b0}};
        temp_rot <= {N{1'b0}};
        original_candidate <= {N{1'b0}};
        is_min <= 1'b0;
        increment_result <= 1'b0;
    end else begin
        // Default values
        done <= done;
        increment_result <= 1'b0;
        
        case (state)
            STATE_IDLE: begin
                done <= 1'b0;
                config_counter <= 6'd0;
                result <= {N{1'b0}};
                if (start) begin
                    // Don't clear result here, it will be cleared in setup
                end
            end
            
            STATE_SETUP: begin
                // Load current candidate from counter
                candidate <= config_counter;
                transformed <= config_counter;
                k_count <= 3'd0;
            end
            
            STATE_TRANSFORM: begin
                // Perform one transformation step
                temp <= transformed;
                k_count <= k_count + 3'd1;
                // Transformation will be applied in comb logic or next cycle
            end
            
            STATE_CHECK: begin
                // Check if transformed matches target
                if (transformed == target) begin
                    // Check if this candidate is minimal rotation
                    min_rot <= candidate;
                    original_candidate <= candidate;
                    rot_idx <= 3'd1;
                    temp_rot <= {candidate[0], candidate[N-1:1]}; // First rotation
                end
            end
            
            STATE_ROTATE: begin
                if (rot_idx < N) begin
                    // Continue rotation
                    temp_rot <= {temp_rot[0], temp_rot[N-1:1]};
                    if (temp_rot < min_rot) min_rot <= temp_rot;
                    rot_idx <= rot_idx + 3'd1;
                end else begin
                    // Final check
                    if (original_candidate <= min_rot) begin
                        increment_result <= 1'b1;
                    end
                end
            end
            
            STATE_NEXT: begin
                if (increment_result) begin
                    result <= result + {N-1'd0, 1'b1};
                end
                if (config_counter < (1 << N) - 1) begin
                    config_counter <= config_counter + 6'd1;
                end
            end
            
            STATE_DONE: begin
                done <= 1'b1;
            end
            
            default: begin
                // Should not happen
                config_counter <= 6'd0;
                result <= {N{1'b0}};
            end
        endcase
    end
end

// Combinational next state logic
always @(*) begin
    next_state = state;
    
    case (state)
        STATE_IDLE: begin
            if (start) next_state = STATE_SETUP;
            else next_state = STATE_IDLE;
        end
        
        STATE_SETUP: begin
            next_state = STATE_TRANSFORM;
        end
        
        STATE_TRANSFORM: begin
            if (k_count < K) begin
                next_state = STATE_TRANSFORM;
            end else begin
                next_state = STATE_CHECK;
            end
        end
        
        STATE_CHECK: begin
            if (transformed == target) begin
                next_state = STATE_ROTATE;
            end else begin
                next_state = STATE_NEXT;
            end
        end
        
        STATE_ROTATE: begin
            if (rot_idx < N) begin
                next_state = STATE_ROTATE;
            end else begin
                next_state = STATE_NEXT;
            end
        end
        
        STATE_NEXT: begin
            if (config_counter < (1 << N) - 1) begin
                next_state = STATE_SETUP;
            end else begin
                next_state = STATE_DONE;
            end
        end
        
        STATE_DONE: begin
            if (!start) next_state = STATE_IDLE;
            else next_state = STATE_DONE;
        end
        
        default: begin
            next_state = STATE_IDLE;
        end
    endcase
end

// Combinational transformation logic
// This computes: new[i] = old[i] XOR old[(i+1)%N]
always @(*) begin
    transformed_next = transformed;
    
    if (state == STATE_TRANSFORM && k_count < K) begin
        // Perform XOR transformation
        transformed_next[0] = transformed[0] ^ transformed[1];
        transformed_next[N-1] = transformed[N-1] ^ transformed[0];
        
        // For internal bits (1 to N-2)
        for (integer i = 1; i < N-1; i = i + 1) begin
            transformed_next[i] = transformed[i] ^ transformed[i+1];
        end
    end
end

// Update transformed register from comb logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        transformed <= {N{1'b0}};
    end else begin
        if (state == STATE_TRANSFORM && k_count < K) begin
            transformed <= transformed_next;
        end
    end
end

endmodule