module binary_search_last(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    input wire [7:0] target,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] INIT       = 3'd1;
    localparam [2:0] MID        = 3'd2;
    localparam [2:0] COMPARE    = 3'd3;
    localparam [2:0] FOUND      = 3'd4;
    localparam [2:0] NOT_FOUND  = 3'd5;
    localparam [2:0] COMPLETE   = 3'd6;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [2:0] low;
    reg [2:0] high;
    reg [2:0] mid_reg;
    reg [7:0] temp_result;
    reg [4:0] cycle_count;  // Max 16 cycles
    
    // Combinational signals
    wire [7:0] arr_mid;
    wire [2:0] mid_calc;
    wire [7:0] mid_plus_one;
    wire [7:0] high_minus_one;
    wire low_gt_high;
    wire arr_mid_gt_target;
    wire arr_mid_eq_target;
    wire arr_mid_lt_target;
    wire max_cycles_reached;

    // Assignments
    assign arr_mid = arr[mid_reg];
    assign mid_calc = (low + high) >> 1;
    assign mid_plus_one = {5'd0, mid_reg} + 8'd1;
    assign high_minus_one = {5'd0, high} - 8'd1;
    assign low_gt_high = (low > high) ? 1'b1 : 1'b0;
    assign arr_mid_gt_target = (arr_mid > target) ? 1'b1 : 1'b0;
    assign arr_mid_eq_target = (arr_mid == target) ? 1'b1 : 1'b0;
    assign arr_mid_lt_target = (arr_mid < target) ? 1'b1 : 1'b0;
    assign max_cycles_reached = (cycle_count >= 5'd16) ? 1'b1 : 1'b0;

    // State register and reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            low <= 3'd0;
            high <= 3'd7;
            mid_reg <= 3'd0;
            result <= 8'd255;
            temp_result <= 8'd255;
            done <= 1'b0;
            cycle_count <= 5'd0;
        end else begin
            state <= next_state;
            
            // Default assignments
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    // Wait for start pulse
                    done <= 1'b0;
                    cycle_count <= 5'd0;
                    if (start) begin
                        // Initialize for new search
                        temp_result <= 8'd255;
                    end
                end
                
                INIT: begin
                    low <= 3'd0;
                    high <= 3'd7;
                    temp_result <= 8'd255;
                    cycle_count <= cycle_count + 5'd1;
                end
                
                MID: begin
                    mid_reg <= mid_calc;
                    cycle_count <= cycle_count + 5'd1;
                end
                
                COMPARE: begin
                    // Compare in next state
                    cycle_count <= cycle_count + 5'd1;
                end
                
                FOUND: begin
                    // Update result, continue searching right
                    temp_result <= {5'd0, mid_reg};
                    low <= mid_plus_one[2:0];
                    cycle_count <= cycle_count + 5'd1;
                end
                
                NOT_FOUND: begin
                    if (arr_mid_gt_target) begin
                        high <= high_minus_one[2:0];
                    end else begin
                        low <= mid_plus_one[2:0];
                    end
                    cycle_count <= cycle_count + 5'd1;
                end
                
                COMPLETE: begin
                    result <= temp_result;
                    done <= 1'b1;
                    cycle_count <= 5'd0;
                end
                
                default: begin
                    state <= IDLE;
                    low <= 3'd0;
                    high <= 3'd7;
                    mid_reg <= 3'd0;
                    result <= 8'd255;
                    temp_result <= 8'd255;
                    done <= 1'b0;
                    cycle_count <= 5'd0;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end else begin
                    next_state = IDLE;
                end
            end
            
            INIT: begin
                next_state = MID;
            end
            
            MID: begin
                next_state = COMPARE;
            end
            
            COMPARE: begin
                if (arr_mid_gt_target) begin
                    next_state = NOT_FOUND;
                end else if (arr_mid_eq_target) begin
                    next_state = FOUND;
                end else begin  // arr_mid < target
                    next_state = NOT_FOUND;
                end
            end
            
            FOUND: begin
                if (low_gt_high || max_cycles_reached) begin
                    next_state = COMPLETE;
                end else begin
                    next_state = MID;
                end
            end
            
            NOT_FOUND: begin
                if (low_gt_high || max_cycles_reached) begin
                    next_state = COMPLETE;
                end else begin
                    next_state = MID;
                end
            end
            
            COMPLETE: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule