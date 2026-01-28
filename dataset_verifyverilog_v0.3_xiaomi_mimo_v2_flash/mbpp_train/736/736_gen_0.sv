module bisect_left (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    input wire [7:0] len,
    input wire [7:0] x,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] SEARCH  = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    reg [1:0] state, next_state;
    reg [7:0] left_reg, right_reg, mid_reg;
    reg [7:0] next_left, next_right, next_mid;
    reg [7:0] arr_val;
    reg comp_result;
    reg [7:0] mid_plus_one;

    // Combinational logic for array element selection
    always @(*) begin
        case (mid_reg)
            8'd0: arr_val = arr_0;
            8'd1: arr_val = arr_1;
            8'd2: arr_val = arr_2;
            8'd3: arr_val = arr_3;
            8'd4: arr_val = arr_4;
            8'd5: arr_val = arr_5;
            8'd6: arr_val = arr_6;
            8'd7: arr_val = arr_7;
            default: arr_val = 8'd0;
        endcase
    end

    // Combinational logic for comparison and next values
    // Pre-calculate mid + 1 to avoid timing issues in SEARCH state
    always @(*) begin
        mid_plus_one = mid_reg + 8'd1;
        
        if (left_reg < right_reg) begin
            comp_result = (arr_val < x);
        end else begin
            comp_result = 1'b0;
        end
    end

    // Next state and output logic
    always @(*) begin
        next_state = state;
        next_left = left_reg;
        next_right = right_reg;
        next_mid = mid_reg;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SEARCH;
                    next_left = 8'd0;
                    next_right = len;
                    // mid is don't care in IDLE, set to 0 for consistency
                    next_mid = 8'd0;
                end
            end
            
            SEARCH: begin
                if (left_reg < right_reg) begin
                    next_state = SEARCH;
                    next_mid = {1'b0, left_reg[7:1]} + {1'b0, right_reg[7:1]}; // mid = (left + right) >> 1
                    
                    // Update bounds based on comparison
                    if (comp_result) begin
                        next_left = mid_plus_one;
                        next_right = right_reg;
                    end else begin
                        next_left = left_reg;
                        next_right = mid_reg;
                    end
                end else begin
                    // Found insertion point
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            left_reg <= 8'd0;
            right_reg <= 8'd0;
            mid_reg <= 8'd0;
            result <= 8'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            left_reg <= next_left;
            right_reg <= next_right;
            mid_reg <= next_mid;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // result is don't care here
                    end
                end
                
                SEARCH: begin
                    // Continue searching, result not yet finalized
                end
                
                FINISH: begin
                    result <= left_reg;
                    done <= 1'b1;
                end
                
                default: begin
                    // Keep outputs stable
                end
            endcase
        end
    end

endmodule