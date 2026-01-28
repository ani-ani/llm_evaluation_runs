module min_days_calculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] p,
    input wire [31:0] q,
    input wire [31:0] a_0, input wire [31:0] b_0,
    input wire [31:0] a_1, input wire [31:0] b_1,
    input wire [31:0] a_2, input wire [31:0] b_2,
    input wire [31:0] a_3, input wire [31:0] b_3,
    input wire [31:0] a_4, input wire [31:0] b_4,
    input wire [31:0] a_5, input wire [31:0] b_5,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_SINGLE = 3'd1;
    localparam [2:0] COMPUTE_PAIRS = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Project arrays (using individual registers for Icarus compatibility)
    reg [31:0] a [0:5];
    reg [31:0] b [0:5];

    // Intermediate results
    reg [31:0] min_days;
    reg [31:0] current_days;
    reg [4:0] i_reg, j_reg;
    reg [31:0] t1, t2;
    reg [31:0] denominator;
    reg [31:0] numerator_t1, numerator_t2;
    reg [31:0] temp_result;

    // Initialize arrays on reset
    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            min_days <= 32'd0;
            
            // Initialize project arrays
            a[0] <= 32'd0; a[1] <= 32'd0; a[2] <= 32'd0; a[3] <= 32'd0; a[4] <= 32'd0; a[5] <= 32'd0;
            b[0] <= 32'd0; b[1] <= 32'd0; b[2] <= 32'd0; b[3] <= 32'd0; b[4] <= 32'd0; b[5] <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Load project data
                        a[0] <= a_0; a[1] <= a_1; a[2] <= a_2; a[3] <= a_3; a[4] <= a_4; a[5] <= a_5;
                        b[0] <= b_0; b[1] <= b_1; b[2] <= b_2; b[3] <= b_3; b[4] <= b_4; b[5] <= b_5;
                        state <= COMPUTE_SINGLE;
                        min_days <= 32'd0;
                        i_reg <= 5'd0;
                    end
                end
                
                COMPUTE_SINGLE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Calculate days for single project
                    if (a[i_reg] != 32'd0 && b[i_reg] != 32'd0) begin
                        // days = max(p/a_i, q/b_i)
                        if (p >= 32'd0 && a[i_reg] > 32'd0) begin
                            temp_result = p / a[i_reg];
                        end else begin
                            temp_result = 32'd0;
                        end
                        
                        if (q >= 32'd0 && b[i_reg] > 32'd0) begin
                            current_days = q / b[i_reg];
                            if (current_days > temp_result) begin
                                temp_result = current_days;
                            end
                        end else begin
                            current_days = 32'd0;
                        end
                        
                        // Update min_days
                        if (min_days == 32'd0 || temp_result < min_days) begin
                            min_days = temp_result;
                        end
                    end
                    
                    // Move to next project
                    i_reg <= i_reg + 5'd1;
                    if (i_reg == 5'd6) begin
                        i_reg <= 5'd0;
                        j_reg <= 5'd1;
                        state <= COMPUTE_PAIRS;
                    end
                end
                
                COMPUTE_PAIRS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Calculate days for project pair (i_reg, j_reg)
                    if (a[i_reg] != 32'd0 && b[i_reg] != 32'd0 && 
                        a[j_reg] != 32'd0 && b[j_reg] != 32'd0) begin
                        
                        // Calculate denominator: D = a_i*b_j - b_i*a_j
                        denominator = $signed(a[i_reg]) * $signed(b[j_reg]) - 
                                     $signed(b[i_reg]) * $signed(a[j_reg]);
                        
                        if (denominator != 32'd0) begin
                            // Calculate numerators
                            numerator_t1 = $signed(p) * $signed(b[j_reg]) - 
                                         $signed(q) * $signed(a[j_reg]);
                            numerator_t2 = $signed(q) * $signed(a[i_reg]) - 
                                         $signed(p) * $signed(b[i_reg]);
                            
                            // Calculate t1 and t2 (fixed-point division)
                            if (denominator != 32'd0) begin
                                t1 = numerator_t1 / denominator;
                                t2 = numerator_t2 / denominator;
                                
                                // Check if t1 and t2 are non-negative
                                if (t1[31] == 1'b0 && t2[31] == 1'b0) begin
                                    current_days = t1 + t2;
                                    
                                    // Update min_days
                                    if (min_days == 32'd0 || current_days < min_days) begin
                                        min_days = current_days;
                                    end
                                end
                            end
                        end
                    end
                    
                    // Move to next pair
                    j_reg <= j_reg + 5'd1;
                    if (j_reg == 5'd6) begin
                        i_reg <= i_reg + 5'd1;
                        j_reg <= i_reg + 5'd1;
                    end
                    
                    if (i_reg == 5'd5 && j_reg == 5'd6) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= min_days;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    result <= 32'd0;
                end
            endcase
            
            // Safety: prevent infinite loops
            if (cycle_count >= MAX_CYCLES) begin
                state <= IDLE;
                done <= 1'b1;
                result <= min_days;
            end
        end
    end
endmodule