module compute_max_height(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [31:0] k_fixed,
    input wire signed [31:0] h_init [0:7],
    input wire [3:0] n,
    output reg signed [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] UPDATE    = 3'd2;
    localparam [2:0] CALC_MAX  = 3'd3;
    localparam [2:0] FINISH    = 3'd4;

    // Registers for heights (8x 32-bit)
    reg signed [31:0] h [0:7];
    reg signed [31:0] next_h [0:7];
    
    // Control registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] cycle_count;      // 0 to 99
    reg [3:0] house_idx;        // 0 to 7
    reg [3:0] load_idx;         // 0 to 7
    
    // Computation registers
    reg signed [31:0] neighbor_sum;
    reg signed [31:0] new_val;
    reg signed [31:0] current_max;
    reg signed [31:0] candidate;
    
    // Helper signals for intermediate calculations
    wire signed [31:0] left_neighbor;
    wire signed [31:0] right_neighbor;
    wire signed [32:0] sum_extended;
    wire signed [31:0] half_sum;
    wire signed [31:0] sum_with_k;
    
    // Boundary handling: if index is 0, left is 0; if index is n-1, right is 0
    // But in our sequential update, we use current values (before update)
    // For simplicity, we calculate neighbors based on current h[] values
    // Index 0: left = 0, right = h[1]
    // Index n-1: left = h[n-2], right = 0
    // Middle: left = h[i-1], right = h[i+1]
    
    // Combinational logic for neighbor sum
    always @(*) begin
        if (house_idx == 0) begin
            neighbor_sum = h[1];  // Left is 0
        end else if (house_idx == n - 1) begin
            neighbor_sum = h[house_idx - 1];  // Right is 0
        end else begin
            neighbor_sum = h[house_idx - 1] + h[house_idx + 1];
        end
    end
    
    // Division by 2 (arithmetic shift right) and add k
    // Note: arithmetic shift right preserves sign
    assign half_sum = neighbor_sum >>> 1;  // Arithmetic shift right
    assign sum_with_k = half_sum + k_fixed;
    
    // Max function
    always @(*) begin
        candidate = h[house_idx];
        if (sum_with_k > candidate)
            new_val = sum_with_k;
        else
            new_val = candidate;
    end
    
    // State transition logic
    always @(*) begin
        next_state = state;  // Default stay in current state
        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD;
            end
            
            LOAD: begin
                if (load_idx >= n)
                    next_state = UPDATE;
            end
            
            UPDATE: begin
                if (cycle_count >= 100 && house_idx >= n)
                    next_state = CALC_MAX;
            end
            
            CALC_MAX: begin
                if (house_idx >= n)
                    next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'sd0;
            cycle_count <= 8'd0;
            house_idx <= 4'd0;
            load_idx <= 4'd0;
            current_max <= 32'sh80000000;  // Initialize to minimum signed value
            
            // Initialize all height registers
            h[0] <= 32'sd0;
            h[1] <= 32'sd0;
            h[2] <= 32'sd0;
            h[3] <= 32'sd0;
            h[4] <= 32'sd0;
            h[5] <= 32'sd0;
            h[6] <= 32'sd0;
            h[7] <= 32'sd0;
            
            next_h[0] <= 32'sd0;
            next_h[1] <= 32'sd0;
            next_h[2] <= 32'sd0;
            next_h[3] <= 32'sd0;
            next_h[4] <= 32'sd0;
            next_h[5] <= 32'sd0;
            next_h[6] <= 32'sd0;
            next_h[7] <= 32'sd0;
        end else begin
            state <= next_state;
            done <= 1'b0;  // Default done is 0
            
            case (state)
                IDLE: begin
                    cycle_count <= 8'd0;
                    house_idx <= 4'd0;
                    load_idx <= 4'd0;
                    current_max <= 32'sh80000000;
                end
                
                LOAD: begin
                    if (load_idx < n) begin
                        h[load_idx] <= h_init[load_idx];
                        next_h[load_idx] <= h_init[load_idx];
                        load_idx <= load_idx + 4'd1;
                    end
                end
                
                UPDATE: begin
                    // In each cycle, update all houses (0 to n-1)
                    if (house_idx < n) begin
                        // Update current house with new value
                        h[house_idx] <= new_val;
                        next_h[house_idx] <= new_val;
                        house_idx <= house_idx + 4'd1;
                    end else begin
                        // All houses updated for this cycle
                        house_idx <= 4'd0;
                        if (cycle_count < 100) begin
                            cycle_count <= cycle_count + 8'd1;
                        end
                    end
                end
                
                CALC_MAX: begin
                    if (house_idx < n) begin
                        if (h[house_idx] > current_max)
                            current_max <= h[house_idx];
                        house_idx <= house_idx + 4'd1;
                    end
                end
                
                FINISH: begin
                    result <= current_max;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule