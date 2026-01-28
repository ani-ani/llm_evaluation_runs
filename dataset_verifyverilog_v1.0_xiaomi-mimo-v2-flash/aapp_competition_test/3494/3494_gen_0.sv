module nearest_tree_finder (
    input clk,
    input rst_n,
    input start,
    input input_valid,
    input [3:0] apple_r,
    input [3:0] apple_c,
    input [63:0] tree_map,
    output reg [7:0] result,
    output reg done,
    output reg [63:0] next_tree_map
);

    // State definitions
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [7:0] min_dist_reg;
    reg [63:0] tree_map_reg;
    reg [3:0] apple_r_reg;
    reg [3:0] apple_c_reg;
    reg computing;
    
    // Internal signals for combinational minimum finding
    wire [7:0] min_dist_wire;
    wire [63:0] next_map_wire;
    
    // Combinational block to find minimum distance and compute next map
    // We unroll the loop for all 64 cells
    integer i;
    reg [7:0] current_min;
    reg [3:0] tree_r;
    reg [3:0] tree_c;
    reg signed [4:0] r_diff;
    reg signed [4:0] c_diff;
    wire [7:0] r_diff_sq;
    wire [7:0] c_diff_sq;
    wire [7:0] dist;
    
    // Assignments for distance calculation
    assign r_diff_sq = r_diff * r_diff;
    assign c_diff_sq = c_diff * c_diff;
    assign dist = r_diff_sq + c_diff_sq;
    
    always @(*) begin
        current_min = 8'd255; // Initialize with max possible value
        
        // Check all 64 positions
        for (i = 0; i < 64; i = i + 1) begin
            if (tree_map_reg[i]) begin
                // Calculate row and column for index i
                tree_r = i / 8;
                tree_c = i % 8;
                
                // Calculate differences
                r_diff = $signed({1'b0, tree_r}) - $signed({1'b0, apple_r_reg});
                c_diff = $signed({1'b0, tree_c}) - $signed({1'b0, apple_c_reg});
                
                // Check if this distance is smaller than current minimum
                // Only update if dist < current_min
                if (dist < current_min) begin
                    current_min = dist;
                end
            end
        end
    end
    
    // Combinational next_map calculation
    assign next_map_wire = tree_map_reg | (64'd1 << (apple_r_reg * 8 + apple_c_reg));
    assign min_dist_wire = current_min;
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            next_tree_map <= 64'd0;
            tree_map_reg <= 64'd0;
            apple_r_reg <= 4'd0;
            apple_c_reg <= 4'd0;
            min_dist_reg <= 8'd0;
            computing <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    computing <= 1'b0;
                    
                    // Start signal triggers computation
                    if (start && input_valid) begin
                        tree_map_reg <= tree_map;
                        apple_r_reg <= apple_r;
                        apple_c_reg <= apple_c;
                        state <= COMPUTE;
                        computing <= 1'b1;
                    end
                end
                
                COMPUTE: begin
                    // Calculate and latch the result in the next cycle
                    // The combinational block above calculates min_dist_wire
                    if (computing) begin
                        min_dist_reg <= min_dist_wire;
                        next_tree_map <= next_map_wire;
                        state <= FINISH;
                    end else begin
                        state <= IDLE;
                    end
                end
                
                FINISH: begin
                    result <= min_dist_reg;
                    done <= 1'b1;
                    state <= IDLE;
                    computing <= 1'b0;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    computing <= 1'b0;
                end
            endcase
        end
    end

endmodule