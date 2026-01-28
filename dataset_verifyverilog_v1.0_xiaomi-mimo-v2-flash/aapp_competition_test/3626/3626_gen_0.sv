module rectangle_intersection (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire signed [31:0] rect_x1 [0:7],
    input wire signed [31:0] rect_y1 [0:7],
    input wire signed [31:0] rect_x2 [0:7],
    input wire signed [31:0] rect_y2 [0:7],
    output reg result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] CHECKING  = 2'd1;
    localparam [1:0] FINISH    = 2'd2;

    // Registers
    reg [1:0] state;
    reg [3:0] i_index;
    reg [3:0] j_index;
    reg found_intersect;
    reg [5:0] cycle_count; // Max 64 cycles for 8x8 pairs
    localparam [5:0] MAX_CYCLES = 6'd63;
    
    // Internal wires for comparison
    wire signed [31:0] x1_i;
    wire signed [31:0] y1_i;
    wire signed [31:0] x2_i;
    wire signed [31:0] y2_i;
    wire signed [31:0] x1_j;
    wire signed [31:0] y1_j;
    wire signed [31:0] x2_j;
    wire signed [31:0] y2_j;
    
    // Combinational comparison logic
    wire is_left_of, is_right_of, is_below, is_above;
    wire pair_intersect;
    
    // Assign current rectangle values from arrays
    assign x1_i = rect_x1[i_index];
    assign y1_i = rect_y1[i_index];
    assign x2_i = rect_x2[i_index];
    assign y2_i = rect_y2[i_index];
    
    assign x1_j = rect_x1[j_index];
    assign y1_j = rect_y1[j_index];
    assign x2_j = rect_x2[j_index];
    assign y2_j = rect_y2[j_index];
    
    // Non-intersection conditions (if any true, no intersection)
    // Rect i is left of j: x2_i <= x1_j
    assign is_left_of = (x2_i <= x1_j);
    // Rect i is right of j: x1_i >= x2_j
    assign is_right_of = (x1_i >= x2_j);
    // Rect i is below j: y2_i <= y1_j
    assign is_below = (y2_i <= y1_j);
    // Rect i is above j: y1_i >= y2_j
    assign is_above = (y1_i >= y2_j);
    
    // Intersection is true when NONE of the above conditions are true
    assign pair_intersect = ~(is_left_of | is_right_of | is_below | is_above);

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            i_index <= 4'd0;
            j_index <= 4'd0;
            found_intersect <= 1'b0;
            cycle_count <= 6'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    i_index <= 4'd0;
                    j_index <= 4'd0;
                    found_intersect <= 1'b0;
                    cycle_count <= 6'd0;
                    result <= 1'b0;
                    if (start) begin
                        if (n > 4'd1) begin
                            state <= CHECKING;
                        end else begin
                            state <= FINISH;
                        end
                    end
                end
                
                CHECKING: begin
                    cycle_count <= cycle_count + 6'd1;
                    
                    // Check if current pair intersects
                    if (pair_intersect) begin
                        found_intersect <= 1'b1;
                    end
                    
                    // Update indices
                    if (j_index < n - 4'd1) begin
                        j_index <= j_index + 4'd1;
                    end else begin
                        j_index <= i_index + 4'd2;
                        i_index <= i_index + 4'd1;
                    end
                    
                    // Check if all pairs processed
                    if ((i_index >= n - 4'd1) || (cycle_count >= MAX_CYCLES)) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    result <= found_intersect;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule