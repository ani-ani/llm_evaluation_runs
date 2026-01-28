module DominoColoringCounter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] s1_in,
    input wire [7:0] s2_in,
    input wire [5:0] idx_in,
    input wire is_last,
    output reg [31:0] result,
    output reg done
);

    // Modulo constant: 1e9+7 = 1000000007
    localparam [31:0] MOD = 32'd1000000007;
    
    // State machine states
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    // Previous state: 0=vertical, 1=horizontal
    localparam [0:0] PREV_VERTICAL = 1'b0;
    localparam [0:0] PREV_HORIZONTAL = 1'b1;
    
    reg [1:0] state;
    reg [0:0] prev_type;
    reg [5:0] idx_reg;
    reg [7:0] s1_reg;
    reg [7:0] s2_reg;
    reg [31:0] result_reg;
    reg [31:0] temp_mult;
    reg [1:0] mult_step;
    
    // Combinational signals for domino detection
    wire current_vertical;
    wire current_horizontal;
    
    assign current_vertical = (s1_in == s2_in);
    assign current_horizontal = (s1_in != s2_in);
    
    // Multiplication logic (modulo operation)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            temp_mult <= 32'd0;
            mult_step <= 2'd0;
        end else begin
            case (mult_step)
                2'd0: begin
                    // Start multiplication
                    if (state == PROCESS) begin
                        if (current_vertical) begin
                            // Vertical domino
                            if (prev_type == PREV_VERTICAL) begin
                                // Multiply by 2
                                temp_mult <= result_reg[30:0] + result_reg[30:0];
                                mult_step <= 2'd1;
                            end else if (prev_type == PREV_HORIZONTAL) begin
                                // Multiply by 1 (no change)
                                temp_mult <= result_reg;
                                mult_step <= 2'd1;
                            end
                        end else begin
                            // Horizontal domino
                            if (prev_type == PREV_VERTICAL) begin
                                // Multiply by 2
                                temp_mult <= result_reg[30:0] + result_reg[30:0];
                                mult_step <= 2'd1;
                            end else if (prev_type == PREV_HORIZONTAL) begin
                                // Multiply by 3
                                temp_mult <= result_reg[30:0] + result_reg[30:0] + result_reg;
                                mult_step <= 2'd1;
                            end
                        end
                    end
                end
                2'd1: begin
                    // Apply modulo
                    if (temp_mult >= MOD) begin
                        temp_mult <= temp_mult - MOD;
                    end else begin
                        temp_mult <= temp_mult;
                    end
                    mult_step <= 2'd2;
                end
                2'd2: begin
                    // Second modulo pass for multiplication overflow
                    if (temp_mult >= MOD) begin
                        temp_mult <= temp_mult - MOD;
                    end
                    mult_step <= 2'd3;
                end
                2'd3: begin
                    // Final modulo check
                    if (temp_mult >= MOD) begin
                        temp_mult <= temp_mult - MOD;
                    end
                    mult_step <= 2'd0;
                end
                default: mult_step <= 2'd0;
            endcase
        end
    end
    
    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            result_reg <= 32'd0;
            done <= 1'b0;
            prev_type <= PREV_VERTICAL;
            idx_reg <= 6'd0;
            s1_reg <= 8'd0;
            s2_reg <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        idx_reg <= idx_in;
                        s1_reg <= s1_in;
                        s2_reg <= s2_in;
                        
                        // Process first domino
                        if (current_vertical) begin
                            result_reg <= 32'd3;
                            result <= 32'd3;
                            prev_type <= PREV_VERTICAL;
                        end else begin
                            result_reg <= 32'd6;
                            result <= 32'd6;
                            prev_type <= PREV_HORIZONTAL;
                        end
                        
                        if (is_last) begin
                            state <= FINISH;
                        end else begin
                            state <= PROCESS;
                        end
                    end
                end
                
                PROCESS: begin
                    if (mult_step == 2'd3) begin
                        // Update result after modulo operation
                        result_reg <= temp_mult;
                        result <= temp_mult;
                        
                        // Update previous type
                        if (current_vertical) begin
                            prev_type <= PREV_VERTICAL;
                        end else begin
                            prev_type <= PREV_HORIZONTAL;
                        end
                        
                        if (is_last) begin
                            state <= FINISH;
                        end else begin
                            // Get next character for next cycle
                            idx_reg <= idx_in;
                            s1_reg <= s1_in;
                            s2_reg <= s2_in;
                            mult_step <= 2'd0;
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule