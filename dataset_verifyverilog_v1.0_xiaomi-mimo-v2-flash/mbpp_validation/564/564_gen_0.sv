module count_unequal_pairs (
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
    input wire [3:0] len,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT      = 3'd1;
    localparam [2:0] COMPARE   = 3'd2;
    localparam [3:0] INCREMENT = 3'd3;
    localparam [2:0] NEXT_PAIR = 3'd4;
    localparam [2:0] FINISH    = 3'd5;

    reg [2:0] state, next_state;
    reg [3:0] i;  // outer loop index
    reg [3:0] j;  // inner loop index
    reg [15:0] temp_result;
    reg [7:0] current_i_val;
    reg [7:0] current_j_val;
    reg comparison_result;
    reg [7:0] cycle_count;

    // Helper function to get array value at index
    function automatic [7:0] get_array_value;
        input [3:0] idx;
        input [7:0] a0, a1, a2, a3, a4, a5, a6, a7;
        begin
            case (idx)
                4'd0: get_array_value = a0;
                4'd1: get_array_value = a1;
                4'd2: get_array_value = a2;
                4'd3: get_array_value = a3;
                4'd4: get_array_value = a4;
                4'd5: get_array_value = a5;
                4'd6: get_array_value = a6;
                4'd7: get_array_value = a7;
                default: get_array_value = 8'd0;
            endcase
        end
    endfunction

    // State transition logic
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
                next_state = COMPARE;
            end
            COMPARE: begin
                if (i < len && j < len && j < 8) begin
                    next_state = INCREMENT;
                end else begin
                    next_state = FINISH;
                end
            end
            INCREMENT: begin
                next_state = NEXT_PAIR;
            end
            NEXT_PAIR: begin
                if (j + 8'd1 < len) begin
                    next_state = COMPARE;
                end else begin
                    if (i + 8'd1 < len) begin
                        next_state = INIT;
                    end else begin
                        next_state = FINISH;
                    end
                end
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
            result <= 16'd0;
            done <= 1'b0;
            temp_result <= 16'd0;
            i <= 4'd0;
            j <= 4'd0;
            current_i_val <= 8'd0;
            current_j_val <= 8'd0;
            comparison_result <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    if (i < len) begin
                        // Start inner loop from i+1
                        j <= i + 8'd1;
                        current_i_val <= get_array_value(i, arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7);
                        state <= COMPARE;
                    end else begin
                        state <= FINISH;
                    end
                end
                
                COMPARE: begin
                    // Get j value
                    current_j_val <= get_array_value(j, arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7);
                    
                    // Compare values
                    if (current_i_val != current_j_val) begin
                        comparison_result <= 1'b1;
                    end else begin
                        comparison_result <= 1'b0;
                    end
                    
                    // Safety timeout
                    if (cycle_count >= 8'd100) begin
                        state <= FINISH;
                    end
                end
                
                INCREMENT: begin
                    if (comparison_result) begin
                        temp_result <= temp_result + 16'd1;
                    end
                    state <= NEXT_PAIR;
                end
                
                NEXT_PAIR: begin
                    if (j + 8'd1 < len) begin
                        j <= j + 8'd1;
                        state <= COMPARE;
                    end else begin
                        i <= i + 8'd1;
                        state <= INIT;
                    end
                end
                
                FINISH: begin
                    result <= temp_result;
                    done <= 1'b1;
                    state <= IDLE;
                    // Reset for next operation
                    temp_result <= 16'd0;
                    i <= 4'd0;
                    j <= 4'd0;
                    cycle_count <= 8'd0;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule